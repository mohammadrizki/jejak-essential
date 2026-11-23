require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "mahasiswa melihat navigasi kompetensi dan portofolio tanpa menu EPA yang nonaktif" do
    sign_in users(:siti)

    get dashboard_path

    assert_response :success
    assert_select "nav[aria-label='Breadcrumb']"
    assert_select "button", text: "Target Kompetensi"
    assert_select "button", text: "Portofolio Saya"
    assert_select "button", text: "Capaian Saya"
    assert_no_match "PERUMUSAN CAPAIAN", response.body
    assert_select "a[href='#{competency_framework_templates_path}']", count: 0
    assert_select "a[href='#{entrustment_decisions_path}']", count: 0
    assert_select "a[href='#{assessment_blueprints_path}']", count: 0
    assert_select "a[href='#{artifact_map_path}']", text: "Peta Artefak Saya"
  end

  test "admin melihat administrasi yang tersedia tanpa kewenangan akademik otomatis" do
    admin = users(:budi)
    grant_scoped_admin!(admin, study_programs(:sarjana_kedokteran), "modules.manage", "integration.manage")
    RolePermission.where(role: roles(:admin), system_permission: SystemPermission.find_by!(key: "curriculum.manage")).delete_all
    sign_in admin

    get dashboard_path
    assert_response :success
    assert_select "a[href='#{admin_wpba_instruments_path}']", count: 0
    assert_select "a[href='#{assessment_blueprints_path}']", count: 0
    assert_select "a[href='#{evidence_requirements_path}']", count: 0
    assert_select "a[href='#{artifact_map_path}']", count: 0
    assert_select "a[href='#{external_evidence_imports_path}']", text: "Impor Bukti Eksternal"
  end

  test "mahasiswa dapat melihat peta artefak turunannya tetapi tidak mengelola Bukti yang Diharapkan" do
    sign_in users(:siti)

    get artifact_map_path
    assert_response :success
    get evidence_requirements_path
    assert_response :redirect
  end

  test "admin dapat membuka peta artefak dan daftar Bukti yang Diharapkan tanpa tabel master artefak" do
    admin = users(:budi)
    grant_scoped_admin!(admin, study_programs(:sarjana_kedokteran), "curriculum.manage")
    sign_in admin

    get artifact_map_path
    assert_response :success
    assert_match "diturunkan dari Blueprint Asesmen", response.body

    get evidence_requirements_path
    assert_response :success
    assert_match "Bukti yang Diharapkan", response.body
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
    assert_select "a[href=?]", evidence_sources_path, text: "Penilaian & Validasi Bukti"
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
    assert_select ".mobile-bottom-nav a[href=?]", student_assessments_path
  end
end
