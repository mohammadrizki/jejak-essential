# frozen_string_literal: true

class EpaPromotionReview < ApplicationRecord
  RECOMMENDATIONS = %w[approved needs_more_evidence not_entrusted].freeze

  belongs_to :epa_promotion
  belongs_to :reviewer, class_name: "User"
  belongs_to :supervision_level, optional: true

  validates :recommendation, inclusion: { in: RECOMMENDATIONS }
  validates :notes, presence: true, length: { minimum: 10 }
  validates :reviewer_id, uniqueness: { scope: :epa_promotion_id }
  validate :prospective_target_for_approval

  private

  def prospective_target_for_approval
    if recommendation == "approved"
      if supervision_level.blank? ||
         supervision_level.supervision_scale_version.use_case != "prospective_entrustment"
        errors.add(:supervision_level, "wajib memakai skala target prospektif untuk rekomendasi setuju")
      end
    elsif supervision_level.present?
      errors.add(:supervision_level, "hanya dipilih untuk rekomendasi setuju")
    end
  end
end
