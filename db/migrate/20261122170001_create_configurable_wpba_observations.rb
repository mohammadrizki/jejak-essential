# frozen_string_literal: true

class CreateConfigurableWpbaObservations < ActiveRecord::Migration[8.1]
  def change
    create_table :wpba_observations do |t|
      t.references :student, null: false, foreign_key: { to_table: :users }
      t.references :observer, null: false, foreign_key: { to_table: :users }
      t.references :clinical_rotation, null: false, foreign_key: true
      t.references :clinical_case, foreign_key: true
      t.references :wpba_instrument_version, null: false, foreign_key: true
      t.bigint :corrects_id
      t.datetime :observed_at, null: false
      t.string :status, default: "draft", null: false
      t.text :activity_summary
      t.jsonb :clinical_context, default: {}, null: false
      t.jsonb :responses, default: {}, null: false
      t.text :overall_feedback
      t.text :action_plan
      t.text :correction_reason
      t.datetime :submitted_at
      t.timestamps

      t.index :corrects_id, unique: true
      t.index [ :student_id, :observed_at ]
      t.index [ :observer_id, :observed_at ]
      t.check_constraint "status IN ('draft', 'submitted')", name: "chk_wpba_observations_status"
    end

    safety_assured do
      add_foreign_key :wpba_observations, :wpba_observations, column: :corrects_id,
        on_delete: :restrict, validate: false, name: "fk_wpba_observations_correction_parent"
      add_reference :evidence_records, :wpba_observation, index: false
      add_foreign_key :evidence_records, :wpba_observations, validate: false
      add_index :evidence_records, [ :evidence_requirement_id, :wpba_observation_id ], unique: true,
        where: "wpba_observation_id IS NOT NULL", name: "idx_evidence_records_requirement_wpba_observation"
    end
  end
end
