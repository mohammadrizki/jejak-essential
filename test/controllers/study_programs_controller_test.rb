require "test_helper"

class StudyProgramsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def sign_in_admin
    admin = users(:budi)
    grant_bootstrapped_system_admin!(admin)
    sign_in admin
    admin
  end

  test "bukan admin ditolak" do
    sign_in users(:dedi) # kaprodi
    get study_programs_path
    assert_response :redirect
  end

  test "admin melihat daftar prodi berkode dan dapat menyunting" do
    sign_in_admin
    get study_programs_path
    assert_response :success
    assert_match "pssk", response.body
    assert_match "pspd", response.body

    patch study_program_path(study_programs(:sarjana_kedokteran)),
          params: { study_program: { name: "Sarjana Kedokteran (S1)", code: "pssk", level: "sarjana" } }
    assert_redirected_to study_programs_path
    assert_equal "Sarjana Kedokteran (S1)", study_programs(:sarjana_kedokteran).reload.name
  end

  test "admin dapat menambahkan program subspesialis" do
    sign_in_admin
    assert_difference "StudyProgram.count", 1 do
      post study_programs_path, params: {
        study_program: { name: "Subspesialis Kardiologi", code: "subsp-kardio", level: "subspesialis" }
      }
    end
    assert_redirected_to study_programs_path
    assert_equal "subspesialis", StudyProgram.find_by!(code: "subsp-kardio").level
  end
end
