require "test_helper"

class RolesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:budi)
    grant_bootstrapped_system_admin!(@user)
    sign_in @user
  end

  test "berpindah ke peran yang dimiliki" do
    patch switch_roles_path, params: { role_code: "admin" }

    assert_redirected_to dashboard_path
    assert_equal roles(:admin), @user.reload.active_role
  end

  test "menolak berpindah ke peran yang tidak dimiliki" do
    @user.update!(active_role: roles(:dosen))
    patch switch_roles_path, params: { role_code: "mahasiswa" }

    assert_equal roles(:dosen), @user.reload.active_role
  end
end
