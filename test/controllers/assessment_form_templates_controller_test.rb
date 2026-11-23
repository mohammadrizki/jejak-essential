require "test_helper"

class AssessmentFormTemplatesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "mahasiswa dan dosen tidak bisa membuka Form Builder maupun mengisi formulir" do
    template = assessment_form_templates(:tutor_evaluation)

    [ users(:siti), users(:budi) ].each do |user|
      sign_in user

      get assessment_form_templates_path
      assert_redirected_to root_path
      get assessment_form_template_path(template)
      assert_redirected_to root_path
      get new_assessment_form_template_path
      assert_redirected_to root_path
      get new_assessment_form_template_assessment_form_submission_path(template)
      assert_redirected_to root_path
    end
  end

  test "menu Form Builder hanya tampil bagi kaprodi dan admin" do
    sign_in users(:siti)
    get root_path
    assert_select "a[href=?]", assessment_form_templates_path, count: 0

    sign_in users(:dedi)
    get root_path
    assert_select "a[href=?]", assessment_form_templates_path, minimum: 1
  end

  test "kaprodi mengelola formulir seperti admin" do
    sign_in users(:dedi)

    get assessment_form_templates_path
    assert_response :success
    assert_match assessment_form_templates(:tutor_evaluation).name, response.body
    assert_match "+ Formulir Baru", response.body

    assert_difference "AssessmentFormTemplate.count", 1 do
      post assessment_form_templates_path, params: {
        assessment_form_template: { name: "Evaluasi Blok", description: "Evaluasi blok oleh mahasiswa", is_active: true,
          study_program_id: study_programs(:profesi_dokter).id }
      }
    end
    template = AssessmentFormTemplate.order(:id).last
    assert_equal users(:dedi).study_program_id, template.study_program_id

    assert_difference "template.assessment_form_fields.count", 1 do
      post assessment_form_template_assessment_form_fields_path(template), params: {
        assessment_form_field: { label: "Kejelasan tujuan blok", field_type: "rating", required: true }
      }
    end

    get assessment_form_template_path(template)
    assert_response :success
    assert_match "Kejelasan tujuan blok", response.body
  end

  test "admin bisa membuat formulir baru" do
    admin = users(:budi)
    admin.update!(study_program: study_programs(:sarjana_kedokteran))
    grant_bootstrapped_system_admin!(admin)
    admin.roles << roles(:kaprodi)
    sign_in admin

    assert_difference "AssessmentFormTemplate.count", 1 do
      post assessment_form_templates_path, params: {
        assessment_form_template: { name: "Evaluasi Blok", description: "Evaluasi blok oleh mahasiswa", is_active: true }
      }
    end
    assert_nil AssessmentFormTemplate.order(:id).last.study_program_id,
      "template yang dibuat akun admin tetap tingkat institusi, meski akun juga punya role Kaprodi"
  end

  test "Kaprodi hanya dapat melihat template global dan template program studinya" do
    other_kaprodi = User.create!(full_name: "Kaprodi Profesi", email: "kaprodi.profesi.forms@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: study_programs(:profesi_dokter))
    other_kaprodi.roles << roles(:kaprodi)
    other_template = AssessmentFormTemplate.create!(name: "Rubrik Profesi", created_by: other_kaprodi,
      study_program: study_programs(:profesi_dokter))
    global_template = assessment_form_templates(:tutor_evaluation)
    sign_in users(:dedi)

    get assessment_form_templates_path
    assert_response :success
    assert_select "a[href=?]", assessment_form_template_path(global_template), minimum: 1
    assert_select "a[href=?]", assessment_form_template_path(other_template), count: 0

    get assessment_form_template_path(other_template)
    assert_response :not_found
    get edit_assessment_form_template_path(global_template)
    assert_redirected_to root_path
    patch assessment_form_template_path(global_template), params: {
      assessment_form_template: { name: "Perubahan lintas program" }
    }
    assert_redirected_to root_path
    assert_not_equal "Perubahan lintas program", global_template.reload.name
  end

  test "admin dapat menentukan lingkup program pada template dan Kaprodi tidak dapat mengubah lingkupnya" do
    admin = users(:budi)
    grant_bootstrapped_system_admin!(admin)
    sign_in admin

    post assessment_form_templates_path, params: { assessment_form_template: {
      name: "Form Profesi", study_program_id: study_programs(:profesi_dokter).id
    } }
    template = AssessmentFormTemplate.order(:id).last
    assert_equal study_programs(:profesi_dokter), template.study_program

    sign_in users(:dedi)
    patch assessment_form_template_path(template), params: { assessment_form_template: {
      name: "Diambil alih", study_program_id: users(:dedi).study_program_id
    } }
    assert_response :not_found
    assert_equal "Form Profesi", template.reload.name
    assert_equal study_programs(:profesi_dokter).id, template.study_program_id
  end
end
