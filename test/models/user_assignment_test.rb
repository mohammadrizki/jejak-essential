require "test_helper"

class UserAssignmentTest < ActiveSupport::TestCase
  test "assignment scope must be valid for its role and program" do
    rotation = ClinicalRotation.create!(user: users(:siti), preceptor: users(:wati),
      academic_period: academic_periods(:current_period), station_name: "Rotasi Uji Penugasan",
      start_date: Date.current, end_date: 2.days.from_now.to_date)
    assignment = UserAssignment.new(user: users(:dedi), assigned_by: users(:dedi),
      study_program: users(:siti).study_program, assignment_role: "epa_panel_member",
      scope_type: "ClinicalRotation", scope_id: rotation.id, reason: "Scope ini tidak cocok bagi anggota panel.")

    assert_not assignment.valid?
    assert_includes assignment.errors[:scope_type], "tidak sesuai dengan jenis penugasan"
  end

  test "revocation records actor and timestamp without deleting the assignment" do
    assignment = UserAssignment.create!(user: users(:budi), assigned_by: users(:dedi),
      study_program: users(:siti).study_program, assignment_role: "artifact_reviewer",
      scope_type: "User", scope_id: users(:siti).id, reason: "Review artefak pada mahasiswa bimbingan.")

    assignment.revoke!(by: users(:dedi), reason: "Penugasan berakhir setelah rotasi selesai.")

    assert_equal users(:dedi), assignment.reload.revoked_by
    assert_not_nil assignment.revoked_at
    assert_not UserAssignment.active.exists?(assignment.id)
  end

  test "explicit WPBA assignment authorizes an academic assessor without requiring preceptor_id match" do
    rotation = ClinicalRotation.create!(user: users(:siti), preceptor: users(:wati),
      academic_period: academic_periods(:current_period), station_name: "Rotasi Assignment WPBA",
      start_date: Date.current, end_date: 2.days.from_now.to_date)
    assessor = User.create!(full_name: "Dosen Penilai Ditugaskan", email: "wpba-assessor@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: users(:siti).study_program)
    assessor.roles << roles(:dosen)
    UserAssignment.create!(user: assessor, assigned_by: users(:dedi), study_program: users(:siti).study_program,
      assignment_role: "wpba_assessor", scope_type: "ClinicalRotation", scope_id: rotation.id,
      reason: "Ditugaskan sebagai penilai WPBA pada rotasi ini.")

    assert AssessmentAssignment.assigned?(assessor: assessor, student: users(:siti), rotation: rotation)
    assert_includes AssessmentAssignment.rotations_for(assessor), rotation
  end

  test "external data manager assignment is limited to an authorized education staff member and program" do
    staff = User.create!(full_name: "Petugas Data", email: "petugas-data@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: users(:siti).study_program)
    staff.roles << roles(:tenaga_kependidikan)
    assignment = UserAssignment.create!(user: staff, assigned_by: users(:dedi),
      study_program: users(:siti).study_program, assignment_role: "external_data_manager",
      scope_type: "StudyProgram", scope_id: users(:siti).study_program_id,
      reason: "Ditugaskan untuk rekonsiliasi identifier dan impor bukti semester ini.")

    assert AssignmentAuthorization.assigned?(user: staff, role: "external_data_manager", student: users(:siti))
    assert_not AssignmentAuthorization.assigned?(user: staff, role: "external_data_manager", student: users(:budi))
    assert_equal "external_data_manager", assignment.assignment_role
  end

  test "external data manager role cannot receive clinical assessment assignments" do
    staff = User.create!(full_name: "Petugas Data Kedua", email: "petugas-data2@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: users(:siti).study_program)
    staff.roles << roles(:tenaga_kependidikan)
    assignment = UserAssignment.new(user: staff, assigned_by: users(:dedi),
      study_program: users(:siti).study_program, assignment_role: "wpba_assessor",
      scope_type: "StudyProgram", scope_id: users(:siti).study_program_id,
      reason: "Mencoba memberi akses klinis kepada petugas data tanpa kualifikasi.")

    assert_not assignment.valid?
    assert_includes assignment.errors[:user], "tidak memiliki peran yang sesuai untuk jenis penugasan ini"
  end

  test "external data manager assignment must be program-scoped" do
    staff = User.create!(full_name: "Petugas Data Lingkup Salah", email: "petugas-scope@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: users(:siti).study_program)
    staff.roles << roles(:tenaga_kependidikan)
    assignment = UserAssignment.new(user: staff, assigned_by: users(:dedi),
      study_program: users(:siti).study_program, assignment_role: "external_data_manager",
      scope_type: "User", scope_id: users(:siti).id,
      reason: "Penugasan data harus menggunakan keseluruhan lingkup program studi.")

    assert_not assignment.valid?
    assert_includes assignment.errors[:scope_type], "tidak sesuai dengan jenis penugasan"
  end

  test "admin teknis tidak otomatis menjadi pengusul capaian kompetensi" do
    admin = User.create!(full_name: "Admin Tanpa Otoritas Akademik", email: "admin-proposer@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current)
    admin.roles << roles(:admin)
    student = users(:siti)

    assert_not AssignmentAuthorization.assigned?(user: admin, role: "competency_attainment_proposer", student: student)

    UserAssignment.create!(user: admin, assigned_by: users(:dedi), study_program: student.study_program,
      assignment_role: "competency_attainment_proposer", scope_type: "User", scope_id: student.id,
      reason: "Penugasan eksplisit sebagai pengusul capaian untuk mahasiswa ini.")

    assert AssignmentAuthorization.assigned?(user: admin, role: "competency_attainment_proposer", student: student)
  end
end
