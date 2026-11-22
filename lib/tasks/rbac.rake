# frozen_string_literal: true

namespace :rbac do
  desc "Bootstrap one explicit system superadmin: bin/rails rbac:bootstrap_superadmin[email@example.org]"
  task :bootstrap_superadmin, [:email] => :environment do |_task, args|
    email = args[:email].to_s.strip.downcase
    abort "Gunakan: bin/rails 'rbac:bootstrap_superadmin[email@example.org]'" if email.blank?

    user = User.find_by!(email: email)
    ActiveRecord::Base.transaction do
      superadmin = Role.find_or_create_by!(code: "superadmin") { |role| role.name = "Superadmin" }
      admin = Role.find_by!(code: "admin")
      %w[users.manage roles.manage roles.assign assignments.manage curriculum.manage modules.manage integration.manage audit.read templates.manage].each do |key|
        permission = SystemPermission.find_by!(key: key)
        RolePermission.find_or_create_by!(role: superadmin, system_permission: permission) do |grant|
          grant.scope_level = "system"
        end
      end
      UserRole.find_or_create_by!(user: user, role: superadmin, scope_level: "system", study_program: nil)
      UserRole.find_or_create_by!(user: user, role: admin, scope_level: "system", study_program: nil)
      user.update!(active_role: admin)
      RbacAuditEvent.create!(subject_user: user, event_key: "superadmin.bootstrapped",
        details: { operator: "rbac:bootstrap_superadmin", email: user.email })
    end
    puts "#{user.email} kini memiliki superadmin sistem. Catat tindakan ini pada log operasional institusi."
  end
end
