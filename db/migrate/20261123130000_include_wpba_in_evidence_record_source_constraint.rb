# frozen_string_literal: true

class IncludeWpbaInEvidenceRecordSourceConstraint < ActiveRecord::Migration[8.1]
  SOURCE_COLUMNS = %w[
    assessment_instance_id activity_log_id reflection_entry_id epa_observation_id
    mini_cex_evaluation_id dops_evaluation_id wpba_observation_id
  ].freeze

  def up
    remove_check_constraint :evidence_records, name: "chk_evidence_record_single_source"
    add_check_constraint :evidence_records, source_constraint_sql,
      name: "chk_evidence_record_single_source", validate: false
  end

  def down
    remove_check_constraint :evidence_records, name: "chk_evidence_record_single_source"
    add_check_constraint :evidence_records,
      "num_nonnulls(assessment_instance_id, activity_log_id, reflection_entry_id, epa_observation_id, mini_cex_evaluation_id, dops_evaluation_id) = 1 OR num_nonnulls(assessment_instance_id, activity_log_id, reflection_entry_id, epa_observation_id, mini_cex_evaluation_id, dops_evaluation_id) = 0 AND evidence_source_id IS NOT NULL",
      name: "chk_evidence_record_single_source", validate: false
  end

  private

  def source_constraint_sql
    columns = SOURCE_COLUMNS.join(", ")
    "num_nonnulls(#{columns}) = 1 OR num_nonnulls(#{columns}) = 0 AND evidence_source_id IS NOT NULL"
  end
end
