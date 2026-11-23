# frozen_string_literal: true

class StudentProgramTransfer < ApplicationRecord
  STATUSES = %w[pending accepted rejected cancelled].freeze
  STATUS_LABELS = { "pending" => "Menunggu keputusan", "accepted" => "Diterima", "rejected" => "Ditolak", "cancelled" => "Dibatalkan" }.freeze

  belongs_to :student, class_name: "User"
  belongs_to :source_enrollment, class_name: "StudentProgramEnrollment", inverse_of: :outgoing_transfers
  belongs_to :destination_study_program, class_name: "StudyProgram"
  belongs_to :destination_enrollment, class_name: "StudentProgramEnrollment", optional: true,
    inverse_of: :destination_transfers
  belongs_to :requested_by, class_name: "User"
  belongs_to :decided_by, class_name: "User", optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :destination_cohort_year,
    numericality: { only_integer: true, greater_than: 1950, less_than_or_equal_to: ->(_record) { Date.current.year + 1 } },
    allow_nil: true
  validate :source_is_graduated_and_owned
  validate :destination_is_different
  validate :accepted_transfer_has_destination_enrollment

  scope :pending, -> { where(status: "pending") }

  def status_label = STATUS_LABELS.fetch(status, status)

  def accept!(by:)
    StudentTransferWorkflow.new.accept!(transfer: self, by: by)
  end

  def reject!(by:, reason:)
    StudentTransferWorkflow.new.reject!(transfer: self, by: by, reason: reason)
  end

  private

  def source_is_graduated_and_owned
    return if source_enrollment.blank? || student.blank?
    return if source_enrollment.user_id == student_id && source_enrollment.status == "graduated"

    errors.add(:source_enrollment, "harus merupakan riwayat kelulusan mahasiswa ini")
  end

  def destination_is_different
    return if source_enrollment.blank? || destination_study_program.blank?
    return unless source_enrollment.study_program_id == destination_study_program_id

    errors.add(:destination_study_program, "harus berbeda dari program studi asal")
  end

  def accepted_transfer_has_destination_enrollment
    return unless status == "accepted"

    if destination_enrollment.blank?
      errors.add(:destination_enrollment, "wajib dibuat saat transfer diterima")
      return
    end

    unless destination_enrollment.user_id == student_id && destination_enrollment.study_program_id == destination_study_program_id &&
        destination_enrollment.status == "active"
      errors.add(:destination_enrollment, "harus merupakan keanggotaan aktif mahasiswa di program tujuan")
    end
  end
end
