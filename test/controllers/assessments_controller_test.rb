require "test_helper"

class AssessmentsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "menolak akses tanpa login" do
    get assessments_path
    assert_redirected_to new_user_session_path
  end

  test "mahasiswa hanya melihat evaluasi miliknya sendiri" do
    sign_in users(:siti)
    get assessments_path

    assert_response :success
    assert_match dops_evaluations(:dops_siti_infus).procedure_name, response.body
    assert_match mini_cex_evaluations(:minicex_siti_demam).case_description, response.body
  end

  test "tombol buat evaluasi hanya muncul untuk instruktur" do
    sign_in users(:siti)
    get assessments_path
    assert_no_match "new_dops_evaluation", response.body

    sign_in users(:budi)
    grant_wpba_assessor_permission!(users(:budi), study_programs(:sarjana_kedokteran))
    get assessments_path
    assert_match new_dops_evaluation_path, response.body
  end

  test "draf milik evaluator sendiri muncul di panel Menunggu Diselesaikan" do
    draft = DopsEvaluation.create!(
      student: users(:siti), evaluator: users(:budi), clinical_rotation: clinical_rotations(:ongoing_rotation_siti),
      procedure_name: "Draf Tes", evaluated_at: Date.current, status: "draft",
      scores: { komunikasi: 7, profesionalisme: 7, penilaian_global: 7 }
    )

    sign_in users(:budi)
    get assessments_path
    assert_match "Menunggu Diselesaikan", response.body
    assert_match draft.procedure_name, response.body
  end

  test "modul WPBA nonaktif menyembunyikan tombol input tetapi mempertahankan hasil lama" do
    sign_in users(:budi)
    setting = AppSetting.find_or_initialize_by(key: "module_configuration:study_program:#{users(:siti).study_program_id}")
    setting.value = { "modules" => { "wpba" => false } }
    setting.save!

    get assessments_path

    assert_response :success
    assert_no_match new_dops_evaluation_path, response.body
    assert_no_match new_mini_cex_evaluation_path, response.body
    assert_match dops_evaluations(:dops_siti_infus).procedure_name, response.body
  end

  private

  def grant_wpba_assessor_permission!(user, program)
    permission = SystemPermission.find_or_create_by!(key: "assessment.review") { |record| record.name = "Telaah asesmen" }
    RolePermission.find_or_create_by!(role: roles(:dosen), system_permission: permission) do |grant|
      grant.scope_level = "study_program"
    end
    user.user_roles.find_or_create_by!(role: roles(:dosen), scope_level: "study_program", study_program: program)
  end
end
