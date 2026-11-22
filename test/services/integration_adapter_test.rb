require "test_helper"

class IntegrationAdapterTest < ActiveSupport::TestCase
  test "SIA external identifiers map explicitly to stable JEJAK student IDs" do
    configuration = ModuleConfiguration.for(users(:siti).study_program)
    configuration.update!({ "integration_sia" => true }, actor: users(:dedi))
    mapping = ExternalIdentityResolver.map_student!(source_system: "sia", external_id: "NIM-009",
      student: users(:siti), by: users(:dedi), authority: "integration", revision: "2026-1")

    assert_equal users(:siti), SiaAdapter.new(study_program: users(:siti).study_program)
      .resolve_student!(external_id: "NIM-009")
    assert_equal users(:siti).id, mapping.internal_record_id
    other_student = User.create!(full_name: "Mahasiswa lain", email: "mhs-lain@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: users(:siti).study_program)
    other_student.roles << roles(:mahasiswa)
    assert_raises(ArgumentError) do
      ExternalIdentityResolver.map_student!(source_system: "sia", external_id: "NIM-009",
        student: other_student, by: users(:dedi))
    end
  end

  test "Moodle adapter requires explicit activation and creates unverified canonical evidence" do
    student = users(:siti)
    requirement = EvidenceRequirement.create!(origin: "manual", competency_item: competency_items(:sub_anamnesis),
      source_type: "external", required_count: 1)
    adapter = MoodleAdapter.new(study_program: student.study_program)
    payload = {
      "source_record_id" => "task-99", "source_revision" => "rev-a", "activity_key" => "task:99:siti",
      "student_external_id" => "moodle-siti-1", "occurred_on" => Date.current.iso8601,
      "instrument_code" => "Assignment", "instrument_version" => "2026-A", "score" => 90,
      "result" => "pass", "context" => { "course" => "Keterampilan klinis" }
    }

    assert_raises(ArgumentError) { adapter.ingest!(payload: payload, requirement: requirement) }
    ExternalIdentityResolver.map_student!(source_system: "moodle", external_id: "moodle-siti-1",
      student: student, by: users(:dedi), authority: "integration")
    ModuleConfiguration.for(student.study_program).update!({ "integration_moodle" => true }, actor: users(:dedi))

    record = adapter.ingest!(payload: payload, requirement: requirement)
    assert_equal "unverified", record.evidence_source.validation_status
    assert_equal :in_progress, EvidenceRequirementProgress.new(requirement).call.status
    assert_equal record.id, adapter.ingest!(payload: payload, requirement: requirement).id
  end

  test "EPA eksternal hanya menerima observasi WPBA klinis melalui adapter yang diaktifkan" do
    program = study_programs(:profesi_dokter)
    student = User.create!(full_name: "Mahasiswa WPBA Eksternal", email: "wpba-external@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: program)
    student.roles << roles(:mahasiswa)
    framework = CompetencyFramework.create!(study_program: program,
      name: "Framework WPBA Eksternal", version: "1", education_stage: "profesi")
    epa = framework.epas.create!(code: "EPA-EXT", title: "Melakukan prosedur klinis")
    requirement = EvidenceRequirement.create!(epa: epa, origin: "manual", source_type: "external", required_count: 1)
    admin = users(:budi)
    admin.roles << roles(:admin)
    configuration = ModuleConfiguration.for(program)
    configuration.update!({ "wpba" => "0", "integration_clinical_wpba" => "1" }, actor: admin)
    payload = {
      "source_record_id" => "wba-001", "source_revision" => "1", "activity_key" => "epa-ext-student-1",
      "student" => student, "occurred_on" => Date.current.iso8601,
      "instrument_code" => "Mini-CEX", "instrument_version" => "2026.1",
      "context" => { "supervision_level" => "direct", "complexity" => "moderate" }
    }

    assert_raises(ArgumentError) do
      MoodleAdapter.new(study_program: program).ingest!(payload: payload, requirement: requirement)
    end

    evidence = ClinicalWpbaAdapter.new(study_program: program).ingest!(payload: payload, requirement: requirement)
    assert_equal "clinical_wpba", evidence.evidence_source.source_system
    assert_equal "unverified", evidence.evidence_source.validation_status
  end

  test "reconciliation retains previous identifier mapping history" do
    student = users(:siti)
    mapping = ExternalIdentityResolver.map_student!(source_system: "moodle", external_id: "moodle-correct-1",
      student: student, by: users(:dedi), authority: "manual")
    next_student = User.create!(full_name: "Mahasiswa yang tepat", email: "mhs-tepat@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: student.study_program)
    next_student.roles << roles(:mahasiswa)

    mapping.reconcile!(student: next_student, by: users(:dedi),
      reason: "Konfirmasi dokumen registrasi memastikan identifier milik mahasiswa yang tepat.")

    assert_equal next_student.id, mapping.reload.internal_record_id
    assert_equal student.id, mapping.events.first.previous_internal_record_id
    assert_equal next_student.id, mapping.events.first.new_internal_record_id
  end

  test "assigned education staff can map only students in their assigned program" do
    student = users(:siti)
    staff = User.create!(full_name: "Petugas Rekonsiliasi", email: "petugas-rekonsiliasi@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: student.study_program)
    staff.roles << roles(:tenaga_kependidikan)
    UserAssignment.create!(user: staff, assigned_by: users(:dedi), study_program: student.study_program,
      assignment_role: "external_data_manager", scope_type: "StudyProgram", scope_id: student.study_program_id,
      reason: "Ditugaskan memperbaiki identifier mahasiswa program studi ini.")

    mapping = ExternalIdentityResolver.map_student!(source_system: "moodle", external_id: "M-TENDIK",
      student: student, by: staff)
    assert_equal student.id, mapping.internal_record_id

    other_student = User.create!(full_name: "Mahasiswa program lain", email: "mhs-program-lain@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: study_programs(:profesi_dokter))
    other_student.roles << roles(:mahasiswa)
    assert_raises(ArgumentError) do
      ExternalIdentityResolver.map_student!(source_system: "moodle", external_id: "M-OUTSIDE",
        student: other_student, by: staff)
    end
  end
end
