# frozen_string_literal: true

class AddWpbaEvidenceSources < ActiveRecord::Migration[8.1]
  def change
    add_column :evidence_records, :mini_cex_evaluation_id, :bigint
    add_column :evidence_records, :dops_evaluation_id, :bigint

    add_foreign_key :evidence_records, :mini_cex_evaluations, column: :mini_cex_evaluation_id, validate: false
    add_foreign_key :evidence_records, :dops_evaluations, column: :dops_evaluation_id, validate: false

    safety_assured do
      add_index :evidence_records, :mini_cex_evaluation_id
      add_index :evidence_records, :dops_evaluation_id
      add_index :evidence_records, %i[evidence_requirement_id mini_cex_evaluation_id],
        unique: true, where: "mini_cex_evaluation_id IS NOT NULL", name: "idx_evidence_record_mini_cex_once"
      add_index :evidence_records, %i[evidence_requirement_id dops_evaluation_id],
        unique: true, where: "dops_evaluation_id IS NOT NULL", name: "idx_evidence_record_dops_once"
    end

    safety_assured do
      remove_check_constraint :evidence_records, name: "chk_evidence_record_single_source"
      add_check_constraint :evidence_records,
        "num_nonnulls(assessment_instance_id, activity_log_id, reflection_entry_id, epa_observation_id, mini_cex_evaluation_id, dops_evaluation_id) = 1",
        name: "chk_evidence_record_single_source"
    end

    safety_assured do
      validate_foreign_key :evidence_records, :mini_cex_evaluations
      validate_foreign_key :evidence_records, :dops_evaluations
    end
  end
end
