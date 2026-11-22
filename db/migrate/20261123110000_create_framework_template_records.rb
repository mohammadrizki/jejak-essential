# frozen_string_literal: true

class CreateFrameworkTemplateRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :framework_template_records do |t|
      t.string :name, null: false
      t.text :description, null: false, default: ""
      t.string :source_name, null: false, default: "Adaptasi program studi"
      t.string :source_version, null: false, default: "1"
      t.string :template_version, null: false, default: "1.0.0"
      t.text :attribution, null: false, default: ""
      t.string :education_stage
      t.jsonb :domains, null: false, default: []
      t.jsonb :provenance, null: false, default: {}
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end
    add_index :framework_template_records, :name

    reversible do |direction|
      direction.up do
        safety_assured do
          execute <<~SQL
            INSERT INTO system_permissions (key, name, description, created_at, updated_at)
            VALUES ('templates.manage', 'Kelola pustaka template', 'Menambah, menduplikasi, menyunting, dan menghapus template kerangka kompetensi global.', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            ON CONFLICT (key) DO NOTHING
          SQL
          execute <<~SQL
            INSERT INTO role_permissions (role_id, system_permission_id, scope_level, created_at, updated_at)
            SELECT roles.id, system_permissions.id, 'system', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
            FROM roles CROSS JOIN system_permissions
            WHERE roles.code = 'superadmin' AND system_permissions.key = 'templates.manage'
            ON CONFLICT (role_id, system_permission_id) DO NOTHING
          SQL
        end
      end
      direction.down do
        safety_assured do
          execute <<~SQL
            DELETE FROM role_permissions
            WHERE system_permission_id = (SELECT id FROM system_permissions WHERE key = 'templates.manage')
          SQL
          execute "DELETE FROM system_permissions WHERE key = 'templates.manage'"
        end
      end
    end
  end
end
