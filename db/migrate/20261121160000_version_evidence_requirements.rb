# frozen_string_literal: true

class VersionEvidenceRequirements < ActiveRecord::Migration[8.1]
  def up
    create_table :evidence_requirement_versions do |t|
      t.references :evidence_requirement, null: false, foreign_key: true
      t.integer :version, null: false
      t.jsonb :configuration, null: false, default: {}
      t.timestamps
    end
    add_index :evidence_requirement_versions, %i[evidence_requirement_id version], unique: true,
      name: "idx_evidence_requirement_versions_unique_version"

    safety_assured do
      add_reference :evidence_records, :evidence_requirement_version, index: true
    end

    safety_assured do
      execute <<~SQL
        INSERT INTO evidence_requirement_versions
          (evidence_requirement_id, version, configuration, created_at, updated_at)
        SELECT er.id, 1,
          jsonb_build_object(
            'origin', er.origin,
            'source_type', er.source_type,
            'required_count', er.required_count,
            'fulfillment_rule', er.fulfillment_rule,
            'due_stage', er.due_stage,
            'is_mandatory', er.is_mandatory,
            'status', er.status,
            'competency_item_id', er.competency_item_id,
            'competency_indicator_id', er.competency_indicator_id,
            'epa_id', er.epa_id,
            'blueprint_item_id', er.blueprint_item_id,
            'blueprint_version_id', bi.blueprint_version_id,
            'assessment_method_id', er.assessment_method_id,
            'framework_id', COALESCE(ci.competency_framework_id, epa.competency_framework_id, bv.competency_framework_id),
            'framework_version', cf.version
          ), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        FROM evidence_requirements er
        LEFT JOIN competency_items ci ON ci.id = er.competency_item_id
        LEFT JOIN epas epa ON epa.id = er.epa_id
        LEFT JOIN blueprint_items bi ON bi.id = er.blueprint_item_id
        LEFT JOIN blueprint_versions bv ON bv.id = bi.blueprint_version_id
        LEFT JOIN competency_frameworks cf ON cf.id = COALESCE(ci.competency_framework_id, epa.competency_framework_id, bv.competency_framework_id)
      SQL

      execute <<~SQL
        UPDATE evidence_records record
        SET evidence_requirement_version_id = version.id
        FROM evidence_requirement_versions version
        WHERE version.evidence_requirement_id = record.evidence_requirement_id
          AND version.version = 1
      SQL

      add_foreign_key :evidence_records, :evidence_requirement_versions,
        column: :evidence_requirement_version_id, validate: false
      validate_foreign_key :evidence_records, :evidence_requirement_versions,
        column: :evidence_requirement_version_id
      change_column_null :evidence_records, :evidence_requirement_version_id, false
    end
  end

  def down
    remove_foreign_key :evidence_records, column: :evidence_requirement_version_id
    remove_reference :evidence_records, :evidence_requirement_version
    drop_table :evidence_requirement_versions
  end
end
