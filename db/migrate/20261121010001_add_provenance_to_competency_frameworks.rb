# frozen_string_literal: true

class AddProvenanceToCompetencyFrameworks < ActiveRecord::Migration[8.1]
  def up
    add_column :competency_frameworks, :provenance, :jsonb, default: {}, null: false

    # Preserve rows with stable, explicit legacy identifiers before making
    # identifiers required for all new and existing framework entries.
    safety_assured do
      execute "UPDATE competency_items SET code = 'ITEM-' || id::text WHERE code IS NULL OR btrim(code) = ''"
      execute "UPDATE competency_indicators SET code = 'IND-' || id::text WHERE code IS NULL OR btrim(code) = ''"
      change_column_null :competency_items, :code, false
      change_column_null :competency_indicators, :code, false
    end
  end

  def down
    safety_assured do
      change_column_null :competency_items, :code, true
      change_column_null :competency_indicators, :code, true
    end
    remove_column :competency_frameworks, :provenance
  end
end
