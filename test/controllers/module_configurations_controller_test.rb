require "test_helper"

class ModuleConfigurationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "Kaprodi dapat mengatur modul program studinya" do
    sign_in users(:dedi)

    get edit_module_configuration_path
    assert_response :success

    patch module_configuration_path, params: {
      modules: { clinical_logbook: "0", wpba: "1", epa: "0" }
    }
    assert_redirected_to edit_module_configuration_path(study_program_id: users(:dedi).study_program_id)
    assert_not ModuleConfiguration.for(users(:dedi).study_program).enabled?("clinical_logbook")
  end

  test "EPA dapat dipilih pada formulir aktivasi program Sarjana" do
    sign_in users(:dedi)

    get edit_module_configuration_path

    assert_response :success
    assert_select "input[type=checkbox][name='modules[epa]']:not([disabled])"
    assert_no_match "tidak berlaku untuk jenjang Sarjana", response.body
  end

  test "Kaprodi tidak dapat memilih program studi lain" do
    sign_in users(:dedi)

    get edit_module_configuration_path(study_program_id: study_programs(:profesi_dokter).id)
    assert_response :redirect
    assert_empty ModuleConfigurationChange.where(study_program: study_programs(:profesi_dokter))
  end

  test "WPBA yang dinonaktifkan menghentikan input baru tetapi membiarkan hasil historis dibaca" do
    admin = users(:budi)
    admin.roles << roles(:admin)
    ModuleConfiguration.for(users(:siti).study_program).update!({ wpba: "0" }, actor: admin)
    sign_in users(:siti)

    get new_mini_cex_evaluation_path
    assert_response :redirect

    get dops_evaluation_path(dops_evaluations(:dops_siti_infus))
    assert_response :success
  end

  test "Logbook yang dinonaktifkan menghentikan formulir baru tetapi mempertahankan akses baca" do
    admin = users(:budi)
    admin.roles << roles(:admin)
    ModuleConfiguration.for(users(:siti).study_program).update!({ clinical_logbook: "0" }, actor: admin)
    sign_in users(:siti)

    get new_activity_log_path
    assert_response :redirect

    get activity_log_path(activity_logs(:kegiatan_siti))
    assert_response :success
  end
end
