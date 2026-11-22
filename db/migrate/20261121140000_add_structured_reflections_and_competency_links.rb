# frozen_string_literal: true

class AddStructuredReflectionsAndCompetencyLinks < ActiveRecord::Migration[8.1]
  def change
    add_column :reflection_entries, :what_happened, :text
    add_column :reflection_entries, :what_learned, :text
    add_column :reflection_entries, :what_to_improve, :text
    add_column :reflection_entries, :next_action, :text

    create_table :reflection_entry_competency_tags do |t|
      t.references :reflection_entry, null: false, foreign_key: true
      t.references :competency_item, null: false, foreign_key: true
      t.timestamps
    end
    add_index :reflection_entry_competency_tags, %i[reflection_entry_id competency_item_id], unique: true,
      name: "idx_reflection_competency_tags_unique"
  end
end
