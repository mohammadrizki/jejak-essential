# frozen_string_literal: true

class CreateEpaObservationAndPromotionWorkflow < ActiveRecord::Migration[8.1]
  def change
    create_table :supervision_scale_versions do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :version_label, null: false
      t.string :use_case, null: false # retrospective_observation / prospective_entrustment
      t.text :source_reference
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :supervision_scale_versions, %i[code version_label], unique: true,
              name: "idx_supervision_scale_versions_identity"
    add_check_constraint :supervision_scale_versions,
      "use_case IN ('retrospective_observation', 'prospective_entrustment')",
      name: "chk_supervision_scale_use_case"

    create_table :supervision_levels do |t|
      t.references :supervision_scale_version, null: false, foreign_key: true
      t.integer :ordinal, null: false
      t.string :code, null: false
      t.string :label, null: false
      t.text :description, null: false
      t.timestamps
    end
    add_index :supervision_levels, %i[supervision_scale_version_id ordinal], unique: true,
              name: "idx_supervision_levels_ordinal"
    add_index :supervision_levels, %i[supervision_scale_version_id code], unique: true,
              name: "idx_supervision_levels_code"

    create_table :epa_observations do |t|
      t.references :student, null: false, foreign_key: { to_table: :users }
      t.references :epa, null: false, foreign_key: true
      t.references :observer, null: false, foreign_key: { to_table: :users }
      t.references :clinical_case, foreign_key: true
      t.references :clinical_rotation, foreign_key: true
      t.references :supervision_level, null: false, foreign_key: true
      t.datetime :observed_at, null: false
      t.string :complexity, null: false, default: "routine"
      t.text :activity_scope
      t.text :narrative, null: false
      t.text :strengths
      t.text :areas_to_improve
      t.boolean :safety_flag, null: false, default: false
      t.string :status, null: false, default: "submitted"
      t.datetime :submitted_at
      t.timestamps
    end
    add_index :epa_observations, %i[student_id epa_id observed_at],
              name: "idx_epa_observations_student_epa_date"
    add_index :epa_observations, %i[observer_id status]
    add_check_constraint :epa_observations,
      "complexity IN ('routine', 'moderate', 'complex', 'critical')",
      name: "chk_epa_observation_complexity"
    add_check_constraint :epa_observations,
      "status IN ('draft', 'submitted', 'recorded', 'returned', 'voided')",
      name: "chk_epa_observation_status"

    create_table :epa_promotions do |t|
      t.references :student, null: false, foreign_key: { to_table: :users }
      t.references :epa, null: false, foreign_key: true
      t.references :promoted_by, foreign_key: { to_table: :users }
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "ready"
      t.datetime :eligible_at, null: false
      t.datetime :promoted_at
      t.datetime :reviewed_at
      t.text :notes
      t.timestamps
    end
    add_index :epa_promotions, %i[student_id epa_id], unique: true,
              where: "status IN ('ready', 'promoted', 'under_review')",
              name: "idx_epa_promotions_open_student_epa"
    add_index :epa_promotions, %i[status eligible_at]
    add_check_constraint :epa_promotions,
      "status IN ('ready', 'promoted', 'under_review', 'needs_more_evidence', 'not_entrusted', 'approved')",
      name: "chk_epa_promotion_status"

    add_column :evidence_records, :epa_observation_id, :bigint
    safety_assured { add_index :evidence_records, :epa_observation_id }
    add_foreign_key :evidence_records, :epa_observations, validate: false
    safety_assured { validate_foreign_key :evidence_records, :epa_observations }
    remove_check_constraint :evidence_records, name: "chk_evidence_record_single_source"
    add_check_constraint :evidence_records,
      "num_nonnulls(assessment_instance_id, activity_log_id, reflection_entry_id, epa_observation_id) = 1",
      name: "chk_evidence_record_single_source", validate: false
    remove_check_constraint :evidence_requirements, name: "chk_evidence_requirement_source"
    add_check_constraint :evidence_requirements,
      "source_type IN ('assessment', 'logbook', 'portfolio', 'reflection', 'other', 'epa_observation')",
      name: "chk_evidence_requirement_source", validate: false
    safety_assured do
      validate_check_constraint :evidence_records, name: "chk_evidence_record_single_source"
      validate_check_constraint :evidence_requirements, name: "chk_evidence_requirement_source"
    end
    add_column :entrustment_decisions, :supervision_level_id, :bigint
    add_column :entrustment_decisions, :epa_promotion_id, :bigint
    safety_assured do
      add_index :entrustment_decisions, :supervision_level_id
      add_index :entrustment_decisions, :epa_promotion_id
    end
    add_foreign_key :entrustment_decisions, :supervision_levels, validate: false
    add_foreign_key :entrustment_decisions, :epa_promotions, validate: false
    safety_assured do
      validate_foreign_key :entrustment_decisions, :supervision_levels
      validate_foreign_key :entrustment_decisions, :epa_promotions
    end
  end
end
