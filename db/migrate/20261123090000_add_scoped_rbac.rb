# frozen_string_literal: true

class AddScopedRbac < ActiveRecord::Migration[8.1]
  def change
    safety_assured { add_column :user_roles, :scope_level, :string, null: false, default: "system" }
    safety_assured { add_reference :user_roles, :study_program, foreign_key: true }

    # Legacy admin grants are never promoted to system-wide superadmin.
    # Keep their existing grant, but limit it to the user's own program.
    safety_assured do
      execute <<~SQL
        UPDATE user_roles
        SET scope_level = CASE WHEN users.study_program_id IS NULL THEN 'unassigned' ELSE 'study_program' END,
            study_program_id = users.study_program_id
        FROM roles, users
        WHERE user_roles.role_id = roles.id
          AND user_roles.user_id = users.id
          AND roles.code = 'admin'
      SQL
    end

    safety_assured do
      remove_index :user_roles, name: "index_user_roles_on_user_id_and_role_id"
      add_index :user_roles, %i[user_id role_id], unique: true,
        where: "scope_level = 'system'", name: "idx_user_roles_system_scope"
      add_index :user_roles, %i[user_id role_id], unique: true,
        where: "scope_level = 'unassigned'", name: "idx_user_roles_unassigned_scope"
      add_index :user_roles, %i[user_id role_id study_program_id], unique: true,
        where: "scope_level = 'study_program'", name: "idx_user_roles_program_scope"
      add_check_constraint :user_roles,
        "(scope_level = 'system' AND study_program_id IS NULL) OR " \
        "(scope_level = 'study_program' AND study_program_id IS NOT NULL) OR " \
        "(scope_level = 'unassigned' AND study_program_id IS NULL)",
        name: "chk_user_roles_scope"
    end

    create_table :system_permissions do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description, null: false, default: ""
      t.timestamps
    end
    add_index :system_permissions, :key, unique: true

    create_table :role_permissions do |t|
      t.references :role, null: false, foreign_key: true
      t.references :system_permission, null: false, foreign_key: true
      t.string :scope_level, null: false, default: "study_program"
      t.timestamps
    end
    add_index :role_permissions, %i[role_id system_permission_id], unique: true,
      name: "idx_role_permissions_unique"
    add_check_constraint :role_permissions, "scope_level IN ('system', 'study_program')",
      name: "chk_role_permissions_scope"

    create_table :rbac_audit_events do |t|
      t.references :actor_user, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :subject_user, foreign_key: { to_table: :users, on_delete: :nullify }
      t.bigint :role_id
      t.string :event_key, null: false
      t.jsonb :details, null: false, default: {}
      t.timestamps
    end
    add_index :rbac_audit_events, %i[event_key created_at]
    add_index :rbac_audit_events, :role_id

    # Catalog only: existing role behavior is not silently broadened by this
    # migration. Superadmin configures grants explicitly in the role manager.
    [
      ["users.manage", "Kelola pengguna", "Mengelola akun, status, dan profil pengguna."],
      ["roles.manage", "Kelola peran dan izin", "Mengelola definisi role dan permission role."],
      ["roles.assign", "Berikan role", "Memberikan atau mencabut role pengguna pada lingkup yang diizinkan."],
      ["assignments.manage", "Kelola penugasan", "Mengatur assignment operasional dosen dan preseptor."],
      ["curriculum.manage", "Kelola kurikulum", "Mengelola peta kompetensi, blueprint, dan syarat bukti."],
      ["modules.manage", "Aktivasi modul", "Mengelola modul yang aktif untuk program studi."],
      ["assessment.review", "Telaah asesmen", "Menelaah bukti dan hasil asesmen dalam lingkup assignment."],
      ["assessment.decide", "Keputusan akademik", "Menerbitkan keputusan akademik dalam lingkup kewenangan."],
      ["epa.decide", "Keputusan EPA", "Menerbitkan keputusan entrustment sesuai assignment."],
      ["integration.manage", "Kelola integrasi", "Mengelola konfigurasi dan impor integrasi eksternal."],
      ["audit.read", "Baca audit", "Melihat audit log sesuai cakupan yang diberikan."]
    ].each do |key, name, description|
      safety_assured do
        execute <<~SQL
          INSERT INTO system_permissions (key, name, description, created_at, updated_at)
          VALUES (#{connection.quote(key)}, #{connection.quote(name)}, #{connection.quote(description)}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        SQL
      end
    end
  end
end
