# frozen_string_literal: true

class PortfolioSelection < ApplicationRecord
  VISIBILITIES = %w[private assigned_reviewers].freeze

  belongs_to :artifact_submission
  belongs_to :student, class_name: "User"

  validates :visibility, inclusion: { in: VISIBILITIES }
  validates :selected_at, presence: true
  validate :approved_submission_belongs_to_student

  private

  def approved_submission_belongs_to_student
    return if artifact_submission.blank?
    return if artifact_submission.approved? && artifact_submission.student_id == student_id

    errors.add(:artifact_submission, "harus merupakan artefak disetujui milik mahasiswa")
  end
end
