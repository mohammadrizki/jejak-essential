# frozen_string_literal: true

class CreateExternalMappingEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :external_mapping_events do |t|
      t.references :external_identity_mapping, null: false, foreign_key: true
      t.references :changed_by, null: false, foreign_key: { to_table: :users }
      t.bigint :previous_internal_record_id, null: false
      t.bigint :new_internal_record_id, null: false
      t.text :reason, null: false
      t.datetime :changed_at, null: false
      t.timestamps
    end
    add_index :external_mapping_events, %i[external_identity_mapping_id changed_at],
      name: "idx_external_mapping_change_history"
  end
end
