require "test_helper"

class AssessmentFormSubmissionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "mengisi formulir menyimpan jawaban per pertanyaan" do
    users(:budi).update!(study_program: users(:dedi).study_program)
    sign_in users(:dedi)
    template = assessment_form_templates(:tutor_evaluation)
    rating_field = assessment_form_fields(:kejelasan_materi)

    assert_difference "AssessmentFormSubmission.count", 1 do
      post assessment_form_template_assessment_form_submissions_path(template), params: {
        assessment_form_submission: { subject_user_id: users(:budi).id },
        answers: { rating_field.id.to_s => "4" }
      }
    end

    submission = AssessmentFormSubmission.order(:id).last
    # Satu baris jawaban per PERTANYAAN template (yang opsional boleh kosong),
    # bukan hanya per parameter yang terkirim.
    assert_equal template.assessment_form_fields.count, submission.assessment_form_answers.count
    assert_equal "4", submission.answer_for(rating_field).value
  end

  test "mahasiswa tidak bisa mengirim jawaban formulir" do
    sign_in users(:siti)
    template = assessment_form_templates(:tutor_evaluation)

    assert_no_difference "AssessmentFormSubmission.count" do
      post assessment_form_template_assessment_form_submissions_path(template), params: {
        assessment_form_submission: { subject_user_id: users(:budi).id },
        answers: { assessment_form_fields(:kejelasan_materi).id.to_s => "4" }
      }
    end
    assert_redirected_to root_path
  end

  # Dulu setiap ?subject_user_id= berakhir ArgumentError (Relation#or antar
  # relasi berbeda struktur) → galat 500, sah maupun tidak.
  test "subjek dari ?subject_user_id= terpilih dan ikut di daftar meski bukan dosen" do
    sign_in users(:dedi) # Form Builder: kaprodi & admin
    users(:wati).update!(study_program: users(:dedi).study_program)
    template = assessment_form_templates(:tutor_evaluation)
    siti = users(:siti) # mahasiswa — bukan kandidat bawaan (dosen/preseptor)

    get new_assessment_form_template_assessment_form_submission_path(template, subject_user_id: siti.id)
    assert_response :success
    assert_select "select[name=?] option[selected][value=?]", "assessment_form_submission[subject_user_id]", siti.id.to_s
    assert_select "select[name=?] option[value=?]", "assessment_form_submission[subject_user_id]", users(:wati).id.to_s

    get new_assessment_form_template_assessment_form_submission_path(template, subject_user_id: "bukan-angka")
    assert_response :success
  end

  test "kaprodi tidak dapat memilih atau mengirim formulir untuk subjek di luar prodinya" do
    sign_in users(:dedi)
    template = assessment_form_templates(:tutor_evaluation)
    outside_student = User.create!(full_name: "Mahasiswa Prodi Lain", email: "form-outside@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: study_programs(:profesi_dokter))
    outside_student.roles << roles(:mahasiswa)

    get new_assessment_form_template_assessment_form_submission_path(template, subject_user_id: outside_student.id)
    assert_response :success
    assert_select "select[name=?] option[value=?]", "assessment_form_submission[subject_user_id]", outside_student.id.to_s, count: 0

    assert_no_difference "AssessmentFormSubmission.count" do
      post assessment_form_template_assessment_form_submissions_path(template), params: {
        assessment_form_submission: { subject_user_id: outside_student.id },
        answers: { assessment_form_fields(:kejelasan_materi).id.to_s => "4" }
      }
    end
    assert_redirected_to assessment_form_template_path(template)
  end

  test "Kaprodi hanya melihat jawaban yang terkait dengan prodinya, admin tetap dapat mengaudit semua" do
    template = assessment_form_templates(:tutor_evaluation)
    outside_user = User.create!(full_name: "Pengguna Prodi Lain", email: "form-audit-outside@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: study_programs(:profesi_dokter))
    outside_user.roles << roles(:mahasiswa)
    submission = template.assessment_form_submissions.build(respondent: outside_user,
      subject_user: outside_user, submitted_at: Time.current)
    submission.save!(validate: false)

    sign_in users(:dedi)
    get assessment_form_submissions_path
    assert_response :success
    assert_no_match outside_user.email, response.body
    get assessment_form_submission_path(submission)
    assert_response :redirect

    admin = User.create!(full_name: "Admin Form Audit", email: "form-audit-admin@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current)
    grant_bootstrapped_system_admin!(admin)
    sign_in admin
    get assessment_form_submission_path(submission)
    assert_response :success
  end

  test "pertanyaan wajib yang tidak dipilih tidak lagi lolos diam-diam" do
    sign_in users(:dedi)
    users(:budi).update!(study_program: users(:dedi).study_program)
    template = assessment_form_templates(:tutor_evaluation)

    # Meniru radio yang tidak dipilih: parameternya tidak terkirim sama sekali.
    assert_no_difference "AssessmentFormSubmission.count" do
      post assessment_form_template_assessment_form_submissions_path(template), params: {
        assessment_form_submission: { subject_user_id: users(:budi).id },
        answers: { assessment_form_fields(:saran).id.to_s => "Sudah baik" }
      }
    end
    assert_response :unprocessable_entity
    assert_match "Pertanyaan wajib belum dijawab", response.body
  end

  test "subjek yang dinilai tidak melihat identitas responden pada formulir anonim" do
    submission = AssessmentFormSubmission.new(
      assessment_form_template: assessment_form_templates(:tutor_evaluation),
      respondent: users(:siti), subject_user: users(:budi), submitted_at: Time.current
    )
    submission.assessment_form_answers.build(assessment_form_field: assessment_form_fields(:kejelasan_materi), value: "4")
    submission.save!

    sign_in users(:budi)
    get assessment_form_submission_path(submission)

    assert_response :success
    assert_match "Anonim", response.body
    assert_no_match users(:siti).full_name, response.body
    # Subjek bukan pengelola Form Builder: tautan kembali ke daftar jawaban.
    assert_select "a[href=?]", assessment_form_submissions_path, text: "← Kembali"

    sign_in users(:dedi)
    get assessment_form_submission_path(submission)

    assert_response :success
    assert_match "Anonim", response.body
    assert_no_match users(:siti).full_name, response.body
  end
end
