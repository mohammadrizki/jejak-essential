# frozen_string_literal: true

class AddLifecycleToEntrustmentDecisions < ActiveRecord::Migration[8.1]
  def up
    add_column :entrustment_decisions, :decision_kind, :string, default: "legacy", null: false
    add_column :entrustment_decisions, :decision_status, :string, default: "active", null: false
    add_column :entrustment_decisions, :activity_description, :text
    add_column :entrustment_decisions, :scope_limitations, :text
    add_column :entrustment_decisions, :context, :jsonb, default: {}, null: false
    add_column :entrustment_decisions, :valid_from, :datetime
    add_column :entrustment_decisions, :valid_until, :datetime
    add_column :entrustment_decisions, :revoked_at, :datetime
    safety_assured do
      add_reference :entrustment_decisions, :revoked_by, foreign_key: { to_table: :users }
    end
    add_column :entrustment_decisions, :revocation_reason, :text
    safety_assured do
      add_reference :entrustment_decisions, :revocation_epa_promotion, foreign_key: { to_table: :epa_promotions }
    end

    safety_assured do
      execute <<~SQL
        UPDATE entrustment_decisions
        SET decision_kind = CASE WHEN epa_promotion_id IS NULL THEN 'legacy' ELSE 'summative' END,
            valid_from = created_at,
            decision_status = CASE
              WHEN superseded_by_id IS NOT NULL THEN 'superseded'
              WHEN superseded_at IS NOT NULL THEN 'revoked'
              WHEN epa_promotion_id IS NOT NULL AND EXISTS (
                SELECT 1 FROM epa_promotions promotions
                WHERE promotions.id = entrustment_decisions.epa_promotion_id
                  AND promotions.status = 'restricted'
              ) THEN 'restricted'
              ELSE 'active'
            END,
            revoked_at = CASE WHEN superseded_at IS NOT NULL AND superseded_by_id IS NULL THEN superseded_at END,
            revocation_reason = CASE WHEN superseded_at IS NOT NULL AND superseded_by_id IS NULL
              THEN 'Pencabutan historis; alasan belum tersedia pada skema lama.' END
      SQL
      change_column_null :entrustment_decisions, :valid_from, false
    end

    safety_assured do
      add_check_constraint :entrustment_decisions,
        "decision_kind IN ('legacy', 'ad_hoc', 'summative')", name: "chk_entrustment_decision_kind"
      add_check_constraint :entrustment_decisions,
        "decision_status IN ('active', 'restricted', 'expired', 'revoked', 'superseded')",
        name: "chk_entrustment_decision_status"
      add_check_constraint :entrustment_decisions,
        "valid_until IS NULL OR valid_until > valid_from", name: "chk_entrustment_validity_window"
      add_check_constraint :entrustment_decisions,
        "(decision_status = 'revoked' AND revoked_at IS NOT NULL AND revoked_by_id IS NOT NULL AND length(btrim(coalesce(revocation_reason, ''))) >= 10) OR decision_status <> 'revoked' OR decision_kind = 'legacy'",
        name: "chk_entrustment_revocation_audit"
    end
    safety_assured do
      add_index :entrustment_decisions, %i[student_id epa_id decision_status],
        name: "idx_entrustment_decision_lifecycle"
    end

    create_table :entrustment_decision_events do |t|
      t.references :entrustment_decision, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.string :event_type, null: false
      t.text :reason
      t.jsonb :before_state, default: {}, null: false
      t.jsonb :after_state, default: {}, null: false
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    safety_assured do
      add_check_constraint :entrustment_decision_events,
        "event_type IN ('issued', 'restricted', 'renewed', 'revoked', 'expired', 'corrected', 'superseded')",
        name: "chk_entrustment_decision_event_type"
    end
    add_index :entrustment_decision_events, %i[entrustment_decision_id occurred_at],
      name: "idx_entrustment_decision_events_history"
  end

  def down
    drop_table :entrustment_decision_events
    remove_index :entrustment_decisions, name: "idx_entrustment_decision_lifecycle"
    remove_check_constraint :entrustment_decisions, name: "chk_entrustment_revocation_audit"
    remove_check_constraint :entrustment_decisions, name: "chk_entrustment_validity_window"
    remove_check_constraint :entrustment_decisions, name: "chk_entrustment_decision_status"
    remove_check_constraint :entrustment_decisions, name: "chk_entrustment_decision_kind"
    remove_reference :entrustment_decisions, :revocation_epa_promotion, foreign_key: true
    remove_column :entrustment_decisions, :revocation_reason
    remove_reference :entrustment_decisions, :revoked_by, foreign_key: { to_table: :users }
    remove_column :entrustment_decisions, :revoked_at
    remove_column :entrustment_decisions, :valid_until
    remove_column :entrustment_decisions, :valid_from
    remove_column :entrustment_decisions, :context
    remove_column :entrustment_decisions, :scope_limitations
    remove_column :entrustment_decisions, :activity_description
    remove_column :entrustment_decisions, :decision_status
    remove_column :entrustment_decisions, :decision_kind
  end
end
