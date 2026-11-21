# frozen_string_literal: true

class CreateEvidenceSources < ActiveRecord::Migration[8.1]
  def change
    create_table :evidence_sources do |t|
      t.references :student, null: false, foreign_key: { to_table: :users }
      t.references :assessor, foreign_key: { to_table: :users }
      t.string :source_system, null: false
      t.string :source_type, null: false
      t.string :source_record_id, null: false
      t.string :source_revision, null: false
      t.string :activity_key, null: false
      t.date :occurred_on, null: false
      t.string :validation_status, null: false, default: "unverified"
      t.string :instrument_code
      t.string :instrument_version
      t.decimal :score, precision: 8, scale: 3
      t.string :result
      t.text :feedback
      t.jsonb :context, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}
      t.datetime :validated_at
      t.references :validated_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_check_constraint :evidence_sources,
      "source_type IN ('assessment', 'wpba', 'logbook', 'reflection', 'epa_observation', 'external')",
      name: "chk_evidence_source_type"
    add_check_constraint :evidence_sources,
      "validation_status IN ('unverified', 'validated', 'rejected')",
      name: "chk_evidence_source_validation_status"
    add_index :evidence_sources, %i[source_system source_record_id source_revision],
      unique: true, name: "idx_evidence_sources_external_identity"
    add_index :evidence_sources, %i[source_system activity_key],
      name: "idx_evidence_sources_activity_key"

    add_column :evidence_records, :evidence_source_id, :bigint
    add_foreign_key :evidence_records, :evidence_sources, validate: false
    safety_assured do
      add_index :evidence_records, :evidence_source_id
      add_index :evidence_records, %i[evidence_requirement_id evidence_source_id],
        unique: true, where: "evidence_source_id IS NOT NULL", name: "idx_evidence_record_source_once"
      remove_check_constraint :evidence_records, name: "chk_evidence_record_single_source"
      add_check_constraint :evidence_records,
        "(num_nonnulls(assessment_instance_id, activity_log_id, reflection_entry_id, epa_observation_id, mini_cex_evaluation_id, dops_evaluation_id) = 1) OR (num_nonnulls(assessment_instance_id, activity_log_id, reflection_entry_id, epa_observation_id, mini_cex_evaluation_id, dops_evaluation_id) = 0 AND evidence_source_id IS NOT NULL)",
        name: "chk_evidence_record_single_source", validate: false
    end
    safety_assured do
      validate_foreign_key :evidence_records, :evidence_sources
      validate_check_constraint :evidence_records, name: "chk_evidence_record_single_source"
    end

    safety_assured do
      remove_check_constraint :evidence_requirements, name: "chk_evidence_requirement_source"
      add_check_constraint :evidence_requirements,
        "source_type IN ('assessment', 'wpba', 'logbook', 'portfolio', 'reflection', 'other', 'epa_observation', 'external')",
        name: "chk_evidence_requirement_source", validate: false
      validate_check_constraint :evidence_requirements, name: "chk_evidence_requirement_source"
    end
  end
end
