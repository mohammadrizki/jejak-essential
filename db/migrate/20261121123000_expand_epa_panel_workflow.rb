# frozen_string_literal: true

class ExpandEpaPanelWorkflow < ActiveRecord::Migration[8.1]
  def change
    create_table :epa_promotion_review_events do |t|
      t.references :epa_promotion_review, null: false, foreign_key: true
      t.string :recommendation, null: false
      t.references :supervision_level, foreign_key: true
      t.text :notes, null: false
      t.datetime :recorded_at, null: false
      t.timestamps
    end
    add_check_constraint :epa_promotion_review_events,
      "recommendation IN ('approved', 'restricted', 'needs_more_evidence', 'not_entrusted', 'deferred', 'revoked')",
      name: "chk_epa_panel_event_recommendation"

    safety_assured do
      remove_check_constraint :epa_promotion_reviews, name: "chk_epa_promotion_review_recommendation"
      add_check_constraint :epa_promotion_reviews,
        "recommendation IN ('approved', 'restricted', 'needs_more_evidence', 'not_entrusted', 'deferred', 'revoked')",
        name: "chk_epa_promotion_review_recommendation"
      remove_check_constraint :epa_promotions, name: "chk_epa_promotion_status"
      add_check_constraint :epa_promotions,
        "status IN ('ready', 'promoted', 'under_review', 'needs_more_evidence', 'not_entrusted', 'approved', 'restricted', 'deferred', 'revoked')",
        name: "chk_epa_promotion_status"
    end
  end
end
