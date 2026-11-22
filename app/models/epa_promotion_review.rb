# frozen_string_literal: true

class EpaPromotionReview < ApplicationRecord
  RECOMMENDATIONS = %w[approved restricted needs_more_evidence not_entrusted deferred revoked].freeze

  belongs_to :epa_promotion
  belongs_to :reviewer, class_name: "User"
  belongs_to :supervision_level, optional: true
  has_many :events, class_name: "EpaPromotionReviewEvent", dependent: :restrict_with_error

  validates :recommendation, inclusion: { in: RECOMMENDATIONS }
  validates :notes, presence: true, length: { minimum: 10 }
  validates :reviewer_id, uniqueness: { scope: %i[epa_promotion_id round_number] }
  validate :prospective_target_for_approval
  validate :recusal_reason_required

  def recused?
    recused_at.present?
  end

  private

  def prospective_target_for_approval
    return if recused?

    if recommendation.in?(%w[approved restricted])
      if supervision_level.blank? ||
         supervision_level.supervision_scale_version.use_case != "prospective_entrustment"
        errors.add(:supervision_level, "wajib memakai skala target prospektif untuk rekomendasi setuju")
      end
    elsif supervision_level.present?
      errors.add(:supervision_level, "hanya dipilih untuk rekomendasi setuju atau pembatasan")
    end
  end

  def recusal_reason_required
    return unless recused?

    errors.add(:recusal_reason, "wajib diisi minimal 10 karakter") if recusal_reason.to_s.strip.length < 10
  end
end
