# frozen_string_literal: true

class CreateEpaPromotionReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :epa_promotion_reviews do |t|
      t.references :epa_promotion, null: false, foreign_key: true
      t.references :reviewer, null: false, foreign_key: { to_table: :users }
      t.references :supervision_level, foreign_key: true
      t.string :recommendation, null: false
      t.text :notes, null: false
      t.timestamps
    end
    add_index :epa_promotion_reviews, %i[epa_promotion_id reviewer_id], unique: true,
      name: "idx_epa_promotion_review_member_once"
    add_check_constraint :epa_promotion_reviews,
      "recommendation IN ('approved', 'needs_more_evidence', 'not_entrusted')",
      name: "chk_epa_promotion_review_recommendation"
  end
end
