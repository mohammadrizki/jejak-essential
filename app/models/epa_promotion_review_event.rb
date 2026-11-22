# frozen_string_literal: true

class EpaPromotionReviewEvent < ApplicationRecord
  belongs_to :epa_promotion_review
  belongs_to :supervision_level, optional: true

  validates :event_kind, inclusion: { in: %w[recommendation recusal] }
  validates :recommendation, inclusion: { in: EpaPromotionReview::RECOMMENDATIONS }, if: -> { event_kind == "recommendation" }
  validates :recommendation, absence: true, if: -> { event_kind == "recusal" }
  validates :recommendation, presence: true, if: -> { event_kind == "recommendation" }
  validates :notes, presence: true, length: { minimum: 10 }
  validates :recorded_at, presence: true

  before_update { raise ActiveRecord::ReadOnlyRecord, "Riwayat panel bersifat tetap." }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "Riwayat panel tidak dapat dihapus." }
end
