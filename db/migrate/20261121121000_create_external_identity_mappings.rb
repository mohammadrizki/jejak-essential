# frozen_string_literal: true

class CreateExternalIdentityMappings < ActiveRecord::Migration[8.1]
  def change
    create_table :external_identity_mappings do |t|
      t.string :source_system, null: false
      t.string :entity_type, null: false
      t.string :external_id, null: false
      t.string :internal_record_type, null: false
      t.bigint :internal_record_id, null: false
      t.string :authority, null: false, default: "manual"
      t.string :source_revision
      t.datetime :last_synced_at
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :external_identity_mappings, %i[source_system entity_type external_id], unique: true,
      name: "idx_external_identity_source_once"
    add_index :external_identity_mappings, %i[internal_record_type internal_record_id],
      name: "idx_external_identity_internal_target"
    add_check_constraint :external_identity_mappings,
      "authority IN ('manual', 'import', 'integration')", name: "chk_external_identity_authority"
  end
end
