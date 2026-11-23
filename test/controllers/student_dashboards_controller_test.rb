require "test_helper"

# Dasbor Mahasiswa (hanya-baca) untuk pengajar/kaprodi/admin + halaman
# asesmen yang menerima ?student_id=.
class StudentDashboardsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  STUDENT_PAGES = %i[exam_scores_path assessments_path student_assessments_path student_feedback_journal_path
                     academic_assessments_path].freeze

  test "dosen membuka dasbor mahasiswa: profil, statistik, dan 6 kartu berparameter student_id" do
    EvidenceRequirement.create!(origin: "manual", competency_item: competency_items(:sub_anamnesis),
      source_type: "logbook", required_count: 1)
    sign_in users(:budi)
    siti = users(:siti)
    get student_dashboard_path(siti)
    assert_response :success
    assert_match siti.full_name, response.body
    assert_select '[data-testid="student-stats"]'

    hub = Nokogiri::HTML5(response.body).at_css('[data-testid="assessment-hub"]')
    expected = STUDENT_PAGES.map { |h| send(h, student_id: siti.id) }
    assert_equal expected, hub.css("a").map { |a| a["href"] }
    assert_select '[data-testid="evidence-cycle-summary"]'
  end

  test "EPA Sarjana tampil pada dasbor setelah modul diaktifkan dan tersembunyi saat nonaktif" do
    sign_in users(:siti)
    get student_dashboard_path(users(:siti))
    assert_response :redirect # mahasiswa tidak dapat membuka dasbor administratif

    sign_in users(:budi)
    get student_dashboard_path(users(:siti))
    assert_response :success
    assert_select "a[href=?]", entrustment_decisions_path(student_id: users(:siti).id), 0

    ModuleConfiguration.for(users(:siti).study_program).update!({ epa: "1" }, actor: users(:dedi))
    get student_dashboard_path(users(:siti))
    assert_response :success
    assert_select "a[href=?]", entrustment_decisions_path(student_id: users(:siti).id)

    sign_in users(:siti)
    get entrustment_decisions_path
    assert_response :success
  end

  test "kaprodi bisa membuka; mahasiswa lain dan pengguna non-mahasiswa ditolak" do
    sign_in users(:dedi)
    get student_dashboard_path(users(:siti))
    assert_response :success
    assert_no_match "Sunting akun", response.body

    get student_dashboard_path(users(:budi))
    assert_redirected_to search_path(q: users(:budi).email)

    sign_in users(:siti)
    get student_dashboard_path(users(:siti))
    assert_redirected_to dashboard_path
  end

  test "admin melihat tombol sunting akun" do
    grant_bootstrapped_system_admin!(users(:budi))
    sign_in users(:budi)
    get student_dashboard_path(users(:siti))
    assert_match "Sunting akun", response.body
  end

  test "admin teknis tanpa peran akademik tidak dapat membuka ringkasan nilai dan asesmen mahasiswa" do
    admin = User.create!(full_name: "Admin Teknis Dashboard", email: "admin-teknis-dashboard@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current)
    grant_bootstrapped_system_admin!(admin)
    sign_in admin
    student_id = users(:siti).id

    [student_dashboard_path(student_id), exam_scores_path(student_id: student_id), academic_assessments_path(student_id: student_id),
     student_assessments_path(student_id: student_id), student_feedback_journal_path(student_id: student_id)].each do |path|
      get path
      assert_response :redirect, "#{path} harus menolak admin teknis tanpa peran akademik"
    end

    get student_assessment_path(assessment_instances(:siti_cbt_1), student_id: student_id)
    assert_response :redirect
  end

  test "setiap halaman asesmen menampilkan data mahasiswa yang dipilih beserta banner hanya-baca" do
    sign_in users(:budi)
    siti = users(:siti)
    STUDENT_PAGES.each do |helper|
      get send(helper, student_id: siti.id)
      assert_response :success, "#{helper} gagal"
      assert_select '[data-testid="viewing-student-banner"]', 1, "#{helper} tanpa banner"
      assert_select "a[href=?]", student_dashboard_path(siti)
    end

    get exam_scores_path(student_id: siti.id)
    assert_match assessment_events(:cbt_blok).name, response.body
    detail = student_assessment_path(assessment_instances(:siti_cbt_1), student_id: siti.id)
    assert_select "a[href=?]", detail, minimum: 1, message: "tautan detail harus membawa student_id"
    get detail
    assert_response :success
    get student_assessments_path(student_id: siti.id)
    assert_select "form[action*='register']", 0, "tombol Daftar tidak boleh tampil untuk mahasiswa lain"
  end

  test "detail percobaan mahasiswa lain bisa dilihat tanpa form pengumpulan; submit tetap milik sendiri" do
    sign_in users(:budi)
    mine = assessment_instances(:siti_cbt_1)
    get student_assessment_path(mine, student_id: users(:siti).id)
    assert_response :success
    assert_select "form[action=?]", submit_student_assessment_path(mine), 0

    patch submit_student_assessment_path(mine, student_id: users(:siti).id), params: { self_evaluation: "x" }
    assert_response :not_found
    assert_equal "scored", mine.reload.status
  end

  test "kaprodi tidak bisa membuka mahasiswa di luar prodi binaannya, termasuk lewat student_id" do
    outside_student = User.create!(full_name: "Mahasiswa Profesi Dashboard", email: "profesi-dashboard-scope@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: study_programs(:profesi_dokter),
      active_role: roles(:mahasiswa))
    outside_student.user_roles.create!(role: roles(:mahasiswa), scope_level: "system")
    sign_in users(:dedi)

    get student_dashboard_path(outside_student)
    assert_redirected_to search_path

    STUDENT_PAGES.each do |helper|
      get send(helper, student_id: outside_student.id)
      assert_response :redirect, "#{helper} harus menolak"
      assert_match "tidak memiliki akses", flash[:alert]
    end
  end

  test "student_id yang menunjuk akun bukan-mahasiswa ditolak" do
    sign_in users(:budi)
    get academic_assessments_path(student_id: users(:wati).id)
    assert_response :redirect
    assert_match "tidak memiliki akses", flash[:alert]
  end

  test "student_id diabaikan bagi mahasiswa: tetap melihat data sendiri tanpa banner" do
    sign_in users(:siti)
    get exam_scores_path(student_id: users(:budi).id)
    assert_response :success
    assert_select '[data-testid="viewing-student-banner"]', 0
    assert_match assessment_events(:cbt_blok).name, response.body
  end
end
