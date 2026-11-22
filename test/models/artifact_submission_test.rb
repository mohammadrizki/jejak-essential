require "test_helper"

class ArtifactSubmissionTest < ActiveSupport::TestCase
  test "verified logbook goes through review before the student selects it" do
    log = verified_logbook
    submission = ArtifactSubmission.create!(student: users(:siti), source_type: "ActivityLog",
      source_id: log.id, selection_reason: "Menunjukkan komunikasi dan tindak lanjut klinis.",
      submitted_at: Time.current)
    UserAssignment.create!(user: users(:dedi), assigned_by: users(:dedi),
      study_program: users(:siti).study_program, assignment_role: "artifact_reviewer",
      scope_type: "User", scope_id: users(:siti).id, reason: "Ditunjuk untuk menelaah artefak mahasiswa.")
    policy = ArtifactSubmissionPolicy.new(users(:dedi), submission)
    original_source_version = log.updated_at.utc.iso8601(6)
    log.update!(title: "Judul diperbarui setelah pengajuan")

    assert policy.update?
    assert_equal "Kegiatan tervalidasi", submission.source_title
    assert_equal original_source_version, submission.source_provenance.fetch("source_version_at")
    submission.review!(by: users(:dedi), decision: "approved", notes: "Relevan dan refleksi tindak lanjut jelas.")
    selection = submission.create_portfolio_selection!(student: users(:siti), visibility: "private",
      selected_at: Time.current)

    assert_equal "approved", submission.reload.status
    assert_equal "private", selection.visibility
    assert_equal 1, submission.reviews.count
    assert_not log.destroy
    assert log.errors[:base].any?
    assert_not submission.update(source_id: log.id + 100)
    assert submission.errors[:source_provenance].any?
  end

  test "activity that has not been validated cannot be submitted as an artifact" do
    log = ActivityLog.create!(user: users(:siti), title: "Kegiatan belum valid", category: "klinis",
      activity_type: "Observasi", activity_date: Date.current)
    submission = ArtifactSubmission.new(student: users(:siti), source_type: "ActivityLog",
      source_id: log.id, selection_reason: "Saya ingin menampilkan pengalaman ini kepada pembimbing.",
      submitted_at: Time.current)

    assert_not submission.valid?
    assert_includes submission.errors[:source_id], "kegiatan harus divalidasi sebelum diajukan sebagai artefak"
  end

  test "reviewer assignment is scoped and admin is not automatically a reviewer" do
    student = users(:siti)
    kaprodi = users(:dedi)
    kaprodi.update!(study_program: student.study_program)
    assert_not AssignmentAuthorization.assigned?(user: kaprodi, role: "artifact_reviewer", student: student)
    assert_not AssignmentAuthorization.assigned?(user: users(:budi), role: "artifact_reviewer", student: student)
    admin = User.create!(full_name: "Admin Teknis", email: "admin-teknis@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current)
    admin.roles << roles(:admin)
    assert_not AssignmentAuthorization.assigned?(user: admin, role: "artifact_reviewer", student: student)

    assignment = UserAssignment.create!(user: users(:budi), assigned_by: users(:dedi),
      study_program: student.study_program, assignment_role: "artifact_reviewer",
      scope_type: "User", scope_id: student.id, reason: "Menelaah portofolio mahasiswa bimbingan.")

    assert assignment.matches?(role: "artifact_reviewer", student: student)
    assert AssignmentAuthorization.assigned?(user: users(:budi), role: "artifact_reviewer", student: student)
    assert_not assignment.matches?(role: "artifact_reviewer", student: users(:budi), object: nil)
  end

  private

  def verified_logbook
    log = ActivityLog.create!(user: users(:siti), title: "Kegiatan tervalidasi", category: "klinis",
      activity_type: "Observasi", activity_date: Date.current)
    log.verify!(by: users(:budi))
    log
  end
end
