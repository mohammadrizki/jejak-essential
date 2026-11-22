# frozen_string_literal: true

class AddEpaPanelGovernance < ActiveRecord::Migration[8.1]
  def change
    add_column :epa_promotions, :quorum_reached_at, :datetime
    add_column :epa_promotions, :dossier_snapshot, :jsonb, null: false, default: {}
    add_reference :epa_promotions, :finalized_by, index: false
    safety_assured do
      add_foreign_key :epa_promotions, :users, column: :finalized_by_id, validate: false
    end
    add_column :epa_promotions, :finalized_at, :datetime
    add_column :epa_promotions, :appealed_at, :datetime
    add_column :epa_promotions, :appeal_reason, :text
    add_column :epa_promotions, :review_due_at, :datetime
    add_column :epa_promotions, :review_round, :integer, null: false, default: 1
    add_column :entrustment_decisions, :review_due_at, :datetime

    add_column :epa_promotion_reviews, :conflict_disclosed, :boolean, null: false, default: false
    add_column :epa_promotion_reviews, :recused_at, :datetime
    add_column :epa_promotion_reviews, :recusal_reason, :text
    add_column :epa_promotion_reviews, :round_number, :integer, null: false, default: 1

    add_column :epa_promotion_review_events, :event_kind, :string, null: false, default: "recommendation"
    add_column :epa_promotion_review_events, :conflict_disclosed, :boolean, null: false, default: false
    change_column_null :epa_promotion_review_events, :recommendation, true
    add_check_constraint :epa_promotion_review_events,
      "event_kind IN ('recommendation', 'recusal')", name: "chk_epa_panel_event_kind", validate: false

    create_table :epa_promotion_appeals do |t|
      t.references :epa_promotion, null: false, foreign_key: true
      t.references :appealed_by, null: false, foreign_key: { to_table: :users }
      t.references :resolved_by, foreign_key: { to_table: :users }
      t.integer :round_number, null: false
      t.text :reason, null: false
      t.string :resolution
      t.text :resolution_notes
      t.datetime :resolved_at
      t.timestamps
    end
    add_index :epa_promotion_appeals, %i[epa_promotion_id round_number], unique: true,
      name: "idx_epa_promotion_appeals_round"
    add_check_constraint :epa_promotion_appeals,
      "resolution IS NULL OR resolution IN ('approved', 'restricted', 'needs_more_evidence', 'not_entrusted', 'deferred', 'revoked')",
      name: "chk_epa_promotion_appeal_resolution"

    safety_assured do
      remove_check_constraint :epa_promotions, name: "chk_epa_promotion_status"
      add_check_constraint :epa_promotions,
        "status IN ('ready', 'promoted', 'under_review', 'needs_more_evidence', 'not_entrusted', 'approved', 'restricted', 'deferred', 'revoked', 'appeal_pending')",
        name: "chk_epa_promotion_status"
      remove_index :epa_promotions, name: "idx_epa_promotions_open_student_epa"
      add_index :epa_promotions, %i[student_id epa_id], unique: true,
        where: "status IN ('ready', 'promoted', 'under_review', 'appeal_pending')",
        name: "idx_epa_promotions_open_student_epa"
      remove_index :epa_promotion_reviews, name: "idx_epa_promotion_review_member_once"
      add_index :epa_promotion_reviews, %i[epa_promotion_id reviewer_id round_number], unique: true,
        name: "idx_epa_promotion_review_round_member"
    end
  end
end
