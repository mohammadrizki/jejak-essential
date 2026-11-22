# frozen_string_literal: true

class CreateReflectionEvidenceLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :reflection_entry_evidence_sources do |t|
      t.references :reflection_entry, null: false, foreign_key: true
      t.references :evidence_source, null: false, foreign_key: true
      t.timestamps
    end
    add_index :reflection_entry_evidence_sources, %i[reflection_entry_id evidence_source_id], unique: true,
      name: "idx_reflection_evidence_sources_unique"
  end
end
