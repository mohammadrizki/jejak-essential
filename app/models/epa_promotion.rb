# frozen_string_literal: true

class EpaPromotion < ApplicationRecord
  STATUSES = %w[ready promoted under_review needs_more_evidence not_entrusted approved].freeze
  OPEN_STATUSES = %w[ready promoted under_review].freeze

  belongs_to :student, class_name: "User"
  belongs_to :epa
  belongs_to :promoted_by, class_name: "User", optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true
  has_many :entrustment_decisions, dependent: :restrict_with_error
  has_many :epa_promotion_reviews, dependent: :restrict_with_error

  validates :status, inclusion: { in: STATUSES }
  validates :eligible_at, presence: true
  validate :epa_matches_student

  scope :open, -> { where(status: OPEN_STATUSES) }

  def promote!(by:)
    update!(status: "promoted", promoted_by: by, promoted_at: Time.current)
  end

  private

  def epa_matches_student
    return if epa.blank? || student.blank?
    return if epa.competency_framework.study_program_id == student.study_program_id &&
              epa.competency_framework.education_stage.in?(%w[professional specialist subspecialist]) &&
              epa.competency_framework.status == "published" && epa.status == "published"

    errors.add(:epa, "EPA tidak berlaku bagi program studi mahasiswa")
  end
end
