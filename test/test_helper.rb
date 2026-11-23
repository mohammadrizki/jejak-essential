ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    include ActiveJob::TestHelper

    # Paralel thread pernah bikin deadlock Postgres (thread berebut lock tabel
    # yang sama saat reload fixture) di app sekecil ini — matikan, bukan
    # cuma dikecilkan, karena test suite masih di bawah 1 detik serial.
    parallelize(workers: 1)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all


    # Add more helper methods to be used by all tests here...

    # HTML melarang <form> di dalam <form>: browser mengabaikan pembuka form
    # dalam lalu menutup form LUAR pada </form> pertama, sehingga isian
    # sesudahnya diam-diam tidak ikut terkirim. button_to juga membuat form.
    def assert_no_nested_forms(html)
      depth = 0
      html.scan(%r{<form|</form>}i) do |tag|
        depth += tag.start_with?("</") ? -1 : 1
        assert depth <= 1, "Ada <form> bersarang di dalam <form> lain"
      end
    end

    # RBAC test grants mirror production: a permission grants capability,
    # while the user-role assignment limits where that capability applies.
    def grant_permission_to_role!(role_code, permission_key, scope_level: "system")
      permission = SystemPermission.find_or_create_by!(key: permission_key) do |record|
        record.name = permission_key.humanize
      end
      role = Role.find_by!(code: role_code)
      grant = RolePermission.find_or_initialize_by(role: role, system_permission: permission)
      grant.scope_level = scope_level
      grant.save!
      grant
    end

    def grant_role_in_program!(user, role_code, program)
      user.user_roles.find_or_create_by!(role: Role.find_by!(code: role_code),
        scope_level: "study_program", study_program: program)
    end

    def grant_scoped_admin!(user, program, *permissions)
      grant_role_in_program!(user, "admin", program)
      permissions.each { |key| grant_permission_to_role!("admin", key) }
      user.update!(active_role: Role.find_by!(code: "admin"))
      user
    end

    # Tests for system-wide administration must model the bootstrap path:
    # only an existing superadmin can receive a system-scoped admin grant.
    def grant_bootstrapped_system_admin!(user)
      superadmin = Role.find_by!(code: "superadmin")
      user.user_roles.find_or_create_by!(role: superadmin, scope_level: "system")
      user.user_roles.find_or_create_by!(role: Role.find_by!(code: "admin"), scope_level: "system")
      user.update!(active_role: Role.find_by!(code: "admin"))
      user
    end

  end
end
