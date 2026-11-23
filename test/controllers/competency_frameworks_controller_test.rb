require "test_helper"

class CompetencyFrameworksControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    grant_permission_to_role!("kaprodi", "curriculum.manage")
  end

  test "mahasiswa boleh melihat daftar dan detail (read-only)" do
    sign_in users(:siti)

    get competency_frameworks_path
    assert_response :success

    get competency_framework_path(competency_frameworks(:skdi_ringkas))
    assert_response :success
    assert_match competency_items(:domain_klinis).title, response.body
  end

  test "editor melihat konfigurasi EPA pada framework Sarjana" do
    sign_in users(:dedi)
    framework = competency_frameworks(:skdi_ringkas)
    grant_curriculum_manage!(users(:dedi), framework.study_program)
    enable_epa_module!(framework.study_program)
    framework.epas.create!(code: "EPA-SARJANA-TEST", title: "Aktivitas klinis sarjana", status: "draft")

    get competency_framework_path(framework)

    assert_response :success
    assert_select "h2", text: "EPA pada versi ini"
    assert_select "option[value='sarjana']", text: "Sarjana"
  end

  test "modul EPA nonaktif menyembunyikan input dan menolak perubahan langsung tetapi mempertahankan riwayat" do
    sign_in users(:dedi)
    framework = competency_frameworks(:skdi_ringkas)
    grant_curriculum_manage!(users(:dedi), framework.study_program)
    historical_epa = framework.epas.create!(code: "EPA-HISTORIS", title: "EPA historis", status: "draft")

    get competency_framework_path(framework)

    assert_response :success
    assert_match historical_epa.title, response.body
    assert_match "riwayat baca-saja", response.body
    assert_select "form[action=?]", competency_framework_epas_path(framework), count: 0
    assert_no_match "Tambah pemetaan kompetensi", response.body
    assert_no_match "Tambah target", response.body

    assert_no_difference -> { framework.epas.count } do
      post competency_framework_epas_path(framework), params: {
        epa: { code: "EPA-BLOCKED", title: "Tidak boleh ditambahkan" }
      }
    end
    assert_redirected_to competency_framework_path(framework)
    assert_match "Modul EPA tidak aktif", flash[:alert]
  end

  test "mahasiswa tidak boleh membuat peta kompetensi baru" do
    sign_in users(:siti)
    get new_competency_framework_path
    assert_response :redirect
  end

  test "admin bisa membuat peta kompetensi" do
    admin = grant_scoped_admin!(users(:budi), study_programs(:profesi_dokter), "curriculum.manage")
    sign_in admin

    assert_difference "CompetencyFramework.count", 1 do
      post competency_frameworks_path, params: { competency_framework: { name: "Peta Baru", study_program_id: study_programs(:profesi_dokter).id } }
    end
  end

  test "kaprodi dapat mengelola peta hanya untuk program studinya" do
    sign_in users(:dedi)

    assert_difference "CompetencyFramework.count", 1 do
      post competency_frameworks_path, params: {
        competency_framework: { name: "Peta Prodi Kaprodi", study_program_id: study_programs(:sarjana_kedokteran).id }
      }
    end

    assert_no_difference "CompetencyFramework.count" do
      post competency_frameworks_path, params: {
        competency_framework: { name: "Peta Prodi Lain", study_program_id: study_programs(:profesi_dokter).id }
      }
    end
    assert_response :redirect
  end

  test "admin dapat melihat pratinjau dan menduplikasi framework sebagai draf" do
    admin = grant_scoped_admin!(users(:budi), study_programs(:profesi_dokter), "curriculum.manage")
    grant_scoped_admin!(admin, study_programs(:sarjana_kedokteran), "curriculum.manage")
    sign_in admin
    source = competency_frameworks(:skdi_ringkas)

    get duplicate_competency_framework_path(source)
    assert_response :success
    assert_match "Tinjau framework sumber", response.body

    assert_difference "CompetencyFramework.count", 1 do
      post duplicate_competency_framework_path(source), params: {
        name: "Salinan untuk Profesi", study_program_id: study_programs(:profesi_dokter).id
      }
    end
    copy = CompetencyFramework.order(:created_at).last
    assert_equal "draft", copy.status
    assert_equal "framework_copy", copy.provenance.fetch("kind")
    assert_not_equal source.competency_items.first.id, copy.competency_items.first.id
  end

  test "pengguna non-admin tidak dapat menduplikasi framework" do
    sign_in users(:siti)

    assert_no_difference "CompetencyFramework.count" do
      post duplicate_competency_framework_path(competency_frameworks(:skdi_ringkas)), params: {
        name: "Tidak Diizinkan", study_program_id: study_programs(:profesi_dokter).id
      }
    end
    assert_response :redirect
  end

  private

  def enable_epa_module!(program)
    setting = AppSetting.find_or_initialize_by(key: "module_configuration:study_program:#{program.id}")
    setting.value = { "modules" => { "epa" => true } }
    setting.save!
  end

  def grant_curriculum_manage!(user, program)
    grant_permission_to_role!("kaprodi", "curriculum.manage")
    grant_role_in_program!(user, "kaprodi", program)
  end
end
