# frozen_string_literal: true

class ExternalIdentityMapping < ApplicationRecord
  ENTITY_TYPES = %w[student staff study_program academic_period course assessment_event].freeze
  AUTHORITIES = %w[manual import integration].freeze

  belongs_to :created_by, class_name: "User", optional: true
  has_many :events, class_name: "ExternalMappingEvent", dependent: :restrict_with_error

  validates :source_system, :entity_type, :external_id, :internal_record_type, :internal_record_id, presence: true
  validates :entity_type, inclusion: { in: ENTITY_TYPES }
  validates :authority, inclusion: { in: AUTHORITIES }
  validates :external_id, uniqueness: { scope: %i[source_system entity_type] }
  validate :internal_record_exists

  def internal_record
    return unless internal_record_type == "User"

    User.find_by(id: internal_record_id)
  end

  def reconcile!(student:, by:, reason:)
    raise ArgumentError, "Alasan rekonsiliasi minimal 10 karakter." if reason.to_s.strip.length < 10
    raise ArgumentError, "Target harus mahasiswa." unless student&.has_role?("mahasiswa")
    old = internal_record
    raise ArgumentError, "Pemetaan sudah menunjuk ke mahasiswa tersebut." if old&.id == student.id
    same_program = old&.study_program_id.present? && old.study_program_id == student.study_program_id
    allowed = by.has_role?("superadmin") ||
      (same_program && by.has_permission?("integration.manage", study_program: student.study_program)) ||
      (old&.study_program_id == student.study_program_id &&
        AssignmentAuthorization.assigned?(user: by, role: "external_data_manager", student: student))
    raise Pundit::NotAuthorizedError unless allowed

    self.class.transaction do
      events.create!(changed_by: by, previous_internal_record_id: internal_record_id,
        new_internal_record_id: student.id, reason: reason.to_s.strip, changed_at: Time.current)
      update!(internal_record_type: "User", internal_record_id: student.id,
        authority: "manual", source_revision: "reconciled:#{Time.current.utc.iso8601(6)}")
    end
  end

  private

  def internal_record_exists
    return if internal_record_type.blank? || internal_record_id.blank?
    record = internal_record
    errors.add(:internal_record_id, "tidak menunjuk ke identitas JEJAK yang valid") if record.blank?
    if entity_type == "student" && record.present? && !record.has_role?("mahasiswa")
      errors.add(:internal_record_id, "harus menunjuk ke mahasiswa")
    end
  end
end
