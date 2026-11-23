require "test_helper"

class StudentProgramEnrollmentTest < ActiveSupport::TestCase
  test "bootstrap creates the initial active program membership for a student" do
    student = User.create!(full_name: "Mahasiswa Baru", email: "baru@example.com", password: "rahasia-kuat-1",
      confirmed_at: Time.current, study_program: study_programs(:sarjana_kedokteran), cohort_year: 2025)
    student.user_roles.create!(role: roles(:mahasiswa), scope_level: "system")

    enrollment = StudentProgramEnrollmentBootstrap.ensure_current!(user: student)

    assert_equal "active", enrollment.status
    assert_equal study_programs(:sarjana_kedokteran), enrollment.study_program
    assert_equal Date.new(2025, 1, 1), enrollment.started_on
  end

  test "direct program changes are rejected after student enrollment history exists" do
    student = users(:siti)
    source = study_programs(:sarjana_kedokteran)
    student.update!(study_program: source)
    student.student_program_enrollments.create!(study_program: source, status: "active", started_on: Date.new(2022, 1, 1))

    refute student.update(study_program: study_programs(:profesi_dokter))
    assert_match "alur Transfer Mahasiswa", student.errors.full_messages.to_sentence
    assert_equal source, student.reload.study_program
  end
end
