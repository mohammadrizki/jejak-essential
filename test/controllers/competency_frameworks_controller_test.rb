require "test_helper"

class CompetencyFrameworksControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

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
    framework.epas.create!(code: "EPA-SARJANA-TEST", title: "Aktivitas klinis sarjana", status: "draft")

    get competency_framework_path(framework)

    assert_response :success
    assert_select "h2", text: "EPA pada versi ini"
    assert_select "option[value='undergraduate']", text: "Sarjana"
  end

  test "mahasiswa tidak boleh membuat peta kompetensi baru" do
    sign_in users(:siti)
    get new_competency_framework_path
    assert_response :redirect
  end

  test "admin bisa membuat peta kompetensi" do
    admin = users(:budi)
    admin.roles << roles(:admin)
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
    admin = users(:budi)
    admin.roles << roles(:admin)
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
end
