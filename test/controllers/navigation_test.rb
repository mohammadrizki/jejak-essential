require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "mahasiswa melihat tahap OBE yang sesuai dan tidak melihat menu EPA Sarjana" do
    sign_in users(:siti)

    get dashboard_path

    assert_response :success
    assert_select "nav[aria-label='Breadcrumb']"
    assert_select "button", text: /1\. PERUMUSAN CAPAIAN/
    assert_select "button", text: /2\. PENGEMBANGAN KOMPETENSI/
    assert_select "button", text: /3\. ASESMEN CAPAIAN/
    assert_select "button", text: /4\. EVALUASI & PENINGKATAN MUTU/
    assert_select "a[href='#{competency_framework_templates_path}']", text: "Pustaka Kerangka Kompetensi"
    assert_select "a[href='#{entrustment_decisions_path}']", count: 0
    assert_select "a[href='#{assessment_blueprints_path}']", count: 0
    assert_select "a[href='#{artifact_map_path}']", text: "Peta Artefak Saya"
  end

  test "admin melihat tautan konfigurasi turunan dan breadcrumb tahap" do
    admin = users(:budi)
    admin.roles << roles(:admin)
    admin.update!(active_role: roles(:admin))
    sign_in admin

    get competency_framework_templates_path

    assert_response :success
    assert_select "nav[aria-label='Breadcrumb']", text: /Perumusan Capaian/
    get dashboard_path
    assert_response :success
    assert_select "a[href='#{assessment_blueprints_path}']", text: "Blueprint Asesmen"
    assert_select "a[href='#{evidence_requirements_path}']", text: "Syarat Bukti"
    assert_select "a[href='#{artifact_map_path}']", text: "Peta Artefak"
    assert_select "a[href='#{external_evidence_imports_path}']", text: "Impor Bukti Eksternal"
  end

  test "mahasiswa dapat melihat peta artefak turunannya tetapi tidak mengelola syarat bukti" do
    sign_in users(:siti)

    get artifact_map_path
    assert_response :success
    get evidence_requirements_path
    assert_response :redirect
  end

  test "admin dapat membuka peta artefak dan daftar syarat bukti tanpa tabel master artefak" do
    admin = users(:budi)
    admin.roles << roles(:admin)
    sign_in admin

    get artifact_map_path
    assert_response :success
    assert_match "tampilan turunan", response.body

    get evidence_requirements_path
    assert_response :success
    assert_match "Syarat Bukti", response.body
  end

  test "tenaga kependidikan melihat menu integrasi hanya saat ditugaskan" do
    staff = User.create!(full_name: "Petugas Data Menu", email: "petugas-menu@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: users(:siti).study_program,
      active_role: roles(:tenaga_kependidikan))
    staff.roles << roles(:tenaga_kependidikan)
    sign_in staff
    get dashboard_path

    assert_response :success
    assert_select "a[href=?]", external_evidence_imports_path, 0
    UserAssignment.create!(user: staff, assigned_by: users(:dedi), study_program: users(:siti).study_program,
      assignment_role: "external_data_manager", scope_type: "StudyProgram", scope_id: users(:siti).study_program_id,
      reason: "Ditugaskan mengelola impor bukti untuk program studi semester berjalan.")

    get dashboard_path
    assert_response :success
    assert_select "a[href=?]", external_evidence_imports_path
    assert_select "a[href=?]", external_identity_mappings_path
    assert_select ".mobile-bottom-nav a[href=?]", external_evidence_imports_path
    assert_select ".mobile-bottom-nav a[href=?]", external_identity_mappings_path
    assert_select "a[href=?]", admin_users_path, 0
    assert_select "a[href=?]", clinical_cases_path, 0
  end

  test "penelaah bukti eksternal hanya melihat menu setelah assignment reviewer" do
    reviewer = users(:budi)
    sign_in reviewer
    get dashboard_path
    assert_response :success
    assert_select "a[href=?]", evidence_sources_path, 0

    UserAssignment.create!(user: reviewer, assigned_by: users(:dedi), study_program: users(:siti).study_program,
      assignment_role: "evidence_reviewer", scope_type: "StudyProgram", scope_id: users(:siti).study_program_id,
      reason: "Ditugaskan meninjau provenance bukti eksternal program studi.")
    get dashboard_path
    assert_response :success
    assert_select "a[href=?]", evidence_sources_path, text: "Validasi Bukti Eksternal"
    assert_select ".mobile-bottom-nav a[href=?]", evidence_sources_path
    get evidence_sources_path
    assert_response :success
    assert_select "nav[aria-label='Breadcrumb']", text: /Penilaian & Validasi Bukti/
  end

  test "mahasiswa tetap menemukan riwayat WPBA khusus setelah modul dinonaktifkan" do
    instrument = WpbaInstrument.create!(code: "CUSTOM-NAV-#{SecureRandom.hex(3)}", name: "Observasi klinis", instrument_type: "other")
    version = instrument.versions.create!(version_label: "1.0", definition: {
      "components" => [{ "key" => "quality", "label" => "Mutu", "type" => "rating", "minimum" => 1, "maximum" => 5 }]
    })
    version.publish!(by: users(:budi))
    WpbaObservation.create!(student: users(:siti), observer: users(:budi),
      clinical_rotation: clinical_rotations(:ongoing_rotation_siti), wpba_instrument_version: version,
      observed_at: Time.current, activity_summary: "Konseling pasien", status: "submitted",
      submitted_at: Time.current, responses: { "quality" => 4 })
    ModuleConfiguration.for(users(:siti).study_program).update!({ "wpba" => false }, actor: users(:dedi))
    sign_in users(:siti)

    get dashboard_path

    assert_response :success
    assert_select "a[href=?]", assessments_path
    assert_select ".mobile-bottom-nav a[href=?]", assessments_path
  end
end
