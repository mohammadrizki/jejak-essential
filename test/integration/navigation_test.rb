require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "mahasiswa melihat kelompok menu sasaran dan menu EPA tidak tampil saat modul nonaktif" do
    sign_in users(:siti)
    get dashboard_path

    assert_response :success
    assert_match "Target Kompetensi", response.body
    assert_match "Portofolio Saya", response.body
    assert_match "Capaian Saya", response.body
    assert_no_match "1. PERUMUSAN CAPAIAN", response.body
    assert_select "a[href=?]", competency_frameworks_path
    assert_select "a[href=?]", artifact_map_path
    assert_select "a[href=?]", portfolio_path
    assert_select "a[href=?]", assessments_path
    assert_select "a[href=?]", entrustment_decisions_path, 0
    assert_select "a[href=?]", assessment_blueprints_path, 0
    assert_select "a[href=?]", clinical_rotations_path, 0
    assert_select "a[href=?]", tutorial_enrollments_path, 0
  end

  test "role aktif admin menampilkan administrasi tanpa mewariskan menu role mahasiswa" do
    user = users(:budi)
    user.roles << roles(:admin)
    user.update!(active_role: roles(:admin))
    sign_in user

    get dashboard_path

    assert_response :success
    assert_select "a[href=?]", study_programs_path
    assert_select "a[href=?]", admin_wpba_instruments_path
    assert_select "a[href=?]", edit_module_configuration_path(study_program_id: StudyProgram.ordered.first.id)
    assert_select "a[href=?]", portfolio_path, 0
  end

  test "katalog instrumen WPBA dapat dibuka admin dan ditolak untuk role non-admin" do
    user = users(:budi)
    user.roles << roles(:admin)
    user.update!(active_role: roles(:admin))
    sign_in user

    get admin_wpba_instruments_path

    assert_response :success
    instrument = WpbaInstrument.first
    assert instrument
    get admin_wpba_instrument_path(instrument)
    assert_response :success
    get new_admin_wpba_instrument_path
    assert_response :success

    sign_in users(:siti)
    get admin_wpba_instruments_path
    assert_redirected_to dashboard_path
  end

  test "Peta Artefak mahasiswa hanya menampilkan program studinya dan link Bukti yang Diharapkan milik sendiri" do
    sign_in users(:siti)

    get artifact_map_path, params: { study_program_id: study_programs(:profesi_dokter).id }

    assert_response :success
    assert_match users(:siti).study_program.name, response.body
    assert_no_match study_programs(:profesi_dokter).name, response.body
    assert_select "a[href=?]", portfolio_path(section: "evidence-requirements", anchor: "evidence-requirements")
    assert_select "a[href=?]", evidence_requirements_path, 0
  end
end
