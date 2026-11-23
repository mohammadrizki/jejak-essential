# frozen_string_literal: true

class StudentProgramEnrollment < ApplicationRecord
  STATUSES = %w[active graduated withdrawn suspended].freeze

  belongs_to :user
  belongs_to :study_program
  belongs_to :created_by, class_name: "User", optional: true
  has_many :outgoing_transfers, class_name: "StudentProgramTransfer", foreign_key: :source_enrollment_id,
    inverse_of: :source_enrollment, dependent: :restrict_with_error
  has_many :destination_transfers, class_name: "StudentProgramTransfer", foreign_key: :destination_enrollment_id,
    inverse_of: :destination_enrollment, dependent: :restrict_with_error

  validates :status, inclusion: { in: STATUSES }
  validates :started_on, presence: true
  validates :identifier_number, uniqueness: { scope: :study_program_id }, allow_blank: true
  validate :active_enrollment_matches_current_program
  validate :completion_date_is_valid

  scope :active, -> { where(status: "active") }
  scope :graduated, -> { where(status: "graduated") }

  def graduate!(by:, completed_on: Date.current, reason: nil)
    StudentTransferWorkflow.new.graduate!(enrollment: self, by: by, completed_on: completed_on, reason: reason)
  end

  def active? = status == "active"
  def graduated? = status == "graduated"

  private

  def active_enrollment_matches_current_program
    return unless status == "active" && user && study_program
    return if user.study_program_id == study_program_id

    errors.add(:study_program, "harus sesuai dengan prodi aktif pada akun mahasiswa")
  end

  def completion_date_is_valid
    errors.add(:completed_on, "harus sama atau setelah tanggal mulai") if completed_on && started_on && completed_on < started_on
    errors.add(:completed_on, "wajib diisi untuk status lulus") if status == "graduated" && completed_on.blank?
  end
end
