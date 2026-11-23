require "test_helper"

class ModuleConfigurationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup { grant_program_permission("modules.manage") }

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
    admin = grant_admin_for(users(:siti).study_program)
    ModuleConfiguration.for(users(:siti).study_program).update!({ wpba: "0" }, actor: admin)
    sign_in users(:siti)

    get new_mini_cex_evaluation_path
    assert_response :redirect

    get dops_evaluation_path(dops_evaluations(:dops_siti_infus))
    assert_response :success
  end

  test "Logbook yang dinonaktifkan menghentikan formulir baru tetapi mempertahankan akses baca" do
    admin = grant_admin_for(users(:siti).study_program)
    ModuleConfiguration.for(users(:siti).study_program).update!({ clinical_logbook: "0" }, actor: admin)
    sign_in users(:siti)

    get new_activity_log_path
    assert_response :redirect

    get activity_log_path(activity_logs(:kegiatan_siti))
    assert_response :success
  end

  test "penjadwalan yang dinonaktifkan mempertahankan jadwal sebagai riwayat baca saja" do
    program = users(:dedi).study_program
    grant_program_permission("modules.manage")
    grant_program_permission("assignments.manage")
    event = AssessmentEvent.create!(name: "Jadwal DOPS", assessment_type: "dops",
      academic_period: academic_periods(:current_period), study_program: program, status: "published", max_score: 100)
    schedule = EvaluationSchedule.create!(kind: "dops", student: users(:siti), assessment_event: event,
      scheduled_at: 2.days.from_now)
    ModuleConfiguration.for(program).update!({ "assessment_scheduling" => "0" }, actor: users(:dedi))
    sign_in users(:dedi)

    get admin_evaluation_schedules_path
    assert_response :success
    assert_match "Riwayat · hanya baca", response.body
    assert_no_match edit_admin_evaluation_schedule_path(schedule), response.body

    get edit_admin_evaluation_schedule_path(schedule)
    assert_redirected_to admin_evaluation_schedules_path
    assert_equal "planned", schedule.reload.status

    get new_admin_evaluation_schedule_path
    assert_redirected_to admin_evaluation_schedules_path
  end

  test "detail Event Asesmen WPBA menampilkan jadwal tertaut dan tautan penjadwalan" do
    grant_program_permission("assessment.decide")
    event = AssessmentEvent.create!(name: "DOPS observasi", assessment_type: "dops",
      academic_period: academic_periods(:current_period), study_program: users(:dedi).study_program,
      status: "published", max_score: 100)
    EvaluationSchedule.create!(kind: "dops", student: users(:siti), assessment_event: event,
      scheduled_at: 2.days.from_now)
    sign_in users(:dedi)

    get admin_assessment_event_path(event)

    assert_response :success
    assert_match "Jadwal DOPS/Mini-CEX", response.body
    assert_select "a[href=?]", new_admin_evaluation_schedule_path(assessment_event_id: event.id)
    assert_match users(:siti).full_name, response.body
  end

  private

  def grant_program_permission(key)
    grant_permission_to_role("kaprodi", key)
  end

  def grant_admin_for(program)
    grant_permission_to_role("admin", "modules.manage")
    users(:budi).user_roles.find_or_create_by!(role: roles(:admin), scope_level: "study_program", study_program: program)
    users(:budi)
  end

  def grant_permission_to_role(role_code, key)
    permission = SystemPermission.find_or_create_by!(key: key) { |row| row.name = key.humanize }
    RolePermission.find_or_create_by!(role: roles(role_code), system_permission: permission) do |grant|
      grant.scope_level = "system"
    end
  end
end
