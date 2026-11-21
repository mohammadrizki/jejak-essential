# frozen_string_literal: true

class CreateModuleConfigurationChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :module_configuration_changes do |t|
      t.references :study_program, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.jsonb :before_value, null: false, default: {}
      t.jsonb :after_value, null: false, default: {}
      t.timestamps
    end

    add_index :module_configuration_changes, %i[study_program_id created_at],
      name: "idx_module_config_changes_program_time"
  end
end
