require "test_helper"

class EvidenceRequirementProgressTest < ActiveSupport::TestCase
  test "one actual record cannot satisfy two independent requirements for the same indicator" do
    item = competency_items(:sub_anamnesis)
    indicator = item.competency_indicators.create!(code: "SUB-ANAMNESIS-OBS", description: "Mengamati pemeriksaan", performance_level: "Dengan supervisi")
    shared_rule = { "independence_group" => "independent", "minimum_valid_evidence" => 1 }
    first = EvidenceRequirement.create!(origin: "manual", competency_item: item, competency_indicator: indicator,
                                        source_type: "logbook", required_count: 1, fulfillment_rule: shared_rule)
    second = EvidenceRequirement.create!(origin: "manual", competency_item: item, competency_indicator: indicator,
                                         source_type: "logbook", required_count: 1, fulfillment_rule: shared_rule)
    logbook = verified_logbook
    EvidenceRecord.create!(evidence_requirement: first, activity_log: logbook,
                           evidence_date: Date.current, result: "pass")
    EvidenceRecord.create!(evidence_requirement: second, activity_log: logbook,
                           evidence_date: Date.current, result: "pass")

    assert_equal :fulfilled, EvidenceRequirementProgress.new(first).call.status
    result = EvidenceRequirementProgress.new(second).call
    assert_equal 0, result.record_count
    assert_equal :in_progress, result.status
  end

  test "evidence sufficiency does not create a competency attainment decision" do
    item = competency_items(:sub_anamnesis)
    requirement = EvidenceRequirement.create!(origin: "manual", competency_item: item,
                                               source_type: "logbook", required_count: 1)
    EvidenceRecord.create!(evidence_requirement: requirement, activity_log: verified_logbook,
                           evidence_date: Date.current, result: "pass")

    assert_equal :fulfilled, EvidenceRequirementProgress.new(requirement).call.status
    assert_empty CompetencyAttainment.where(competency_item: item)
  end

  test "student-specific sufficiency excludes evidence belonging to other students" do
    requirement = EvidenceRequirement.create!(origin: "manual", competency_item: competency_items(:sub_anamnesis),
      source_type: "logbook", required_count: 1)
    other = User.create!(full_name: "Mahasiswa Lain", email: "progress.lain@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: study_programs(:sarjana_kedokteran))
    other.roles << roles(:mahasiswa)
    EvidenceRecord.create!(evidence_requirement: requirement, activity_log: verified_logbook(user: other),
      evidence_date: Date.current, result: "pass")

    assert_equal :fulfilled, EvidenceRequirementProgress.new(requirement, student: other).call.status
    result = EvidenceRequirementProgress.new(requirement, student: users(:siti)).call
    assert_equal :not_started, result.status
    assert_equal 0, result.record_count
  end

  test "evidence stays pinned to the requirement version first used by each student" do
    requirement = EvidenceRequirement.create!(origin: "manual", competency_item: competency_items(:sub_anamnesis),
      source_type: "logbook", required_count: 1)
    student = users(:siti)
    first_log = verified_logbook(user: student)
    first_record = EvidenceRecord.create!(evidence_requirement: requirement, activity_log: first_log,
      evidence_date: Date.current, result: "pass")

    requirement.update!(required_count: 2)
    next_log = verified_logbook(user: student)
    next_record = EvidenceRecord.create!(evidence_requirement: requirement, activity_log: next_log,
      evidence_date: Date.current, result: "pass")
    other_student = User.create!(full_name: "Mahasiswa Versi Baru", email: "progress.versi@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: study_programs(:sarjana_kedokteran))
    other_student.roles << roles(:mahasiswa)
    other_record = EvidenceRecord.create!(evidence_requirement: requirement,
      activity_log: verified_logbook(user: other_student), evidence_date: Date.current, result: "pass")

    assert_equal 1, first_record.evidence_requirement_version.version
    assert_equal 1, next_record.evidence_requirement_version.version
    assert_equal 2, other_record.evidence_requirement_version.version
    assert_equal :fulfilled, EvidenceRequirementProgress.new(requirement, student: student).call.status
    assert_equal 1, EvidenceRequirementProgress.new(requirement, student: student).call.required_count
    assert_equal :in_progress, EvidenceRequirementProgress.new(requirement, student: other_student).call.status
    assert_equal 2, EvidenceRequirementProgress.new(requirement, student: other_student).call.required_count
  end

  test "submitted Mini-CEX and DOPS can contribute as distinct WPBA evidence" do
    item = competency_items(:sub_anamnesis)
    requirement = EvidenceRequirement.create!(origin: "manual", competency_item: item,
      source_type: "wpba", required_count: 2)
    mini_cex = mini_cex_evaluations(:minicex_siti_demam)
    dops = dops_evaluations(:dops_siti_infus)
    mini_cex.update!(status: "submitted")
    dops.update!(status: "submitted")

    first = requirement.evidence_records.create!(mini_cex_evaluation: mini_cex,
      evidence_date: mini_cex.evaluated_at, result: "other")
    second = requirement.evidence_records.create!(dops_evaluation: dops,
      evidence_date: dops.evaluated_at, result: "other")

    result = EvidenceRequirementProgress.new(requirement).call
    assert_equal :fulfilled, result.status
    assert_equal 2, result.record_count
    assert_equal ["canonical", "jejak", "mini_cex_evaluation:#{mini_cex.id}"], first.source_key
    assert_equal ["canonical", "jejak", "dops_evaluation:#{dops.id}"], second.source_key
  end

  test "validated external evidence can satisfy an external evidence requirement" do
    requirement = EvidenceRequirement.create!(origin: "manual", competency_item: competency_items(:sub_anamnesis),
      source_type: "external", required_count: 1)
    source = EvidenceSource.create!(student: users(:siti), source_system: "examtool",
      source_record_id: "cbt-result-#{SecureRandom.hex(4)}", source_revision: "1",
      activity_key: "examtool:#{SecureRandom.hex(8)}", source_type: "external", occurred_on: Date.current,
      validation_status: "validated", validated_by: users(:budi), validated_at: Time.current,
      result: "other", instrument_code: "CBT")
    requirement.evidence_records.create!(evidence_source: source, evidence_date: Date.current, result: "other")

    result = EvidenceRequirementProgress.new(requirement, student: users(:siti)).call

    assert_equal :fulfilled, result.status
    assert_equal 1, result.record_count
  end

  test "a saved reflection can count as collected reflection evidence without implying competence attainment" do
    item = competency_items(:sub_anamnesis)
    requirement = EvidenceRequirement.create!(origin: "manual", competency_item: item,
      source_type: "reflection", required_count: 1)
    reflection = reflection_entries(:refleksi_siti)
    requirement.evidence_records.create!(reflection_entry: reflection,
      evidence_date: reflection.entry_date, result: "other")

    assert_equal :fulfilled, EvidenceRequirementProgress.new(requirement, student: reflection.user).call.status
    assert_empty CompetencyAttainment.where(competency_item: item, student: reflection.user)
  end

  test "a requested WPBA observation does not count as valid evidence" do
    item = competency_items(:sub_anamnesis)
    requirement = EvidenceRequirement.create!(origin: "manual", competency_item: item,
      source_type: "wpba", required_count: 1)
    evaluation = mini_cex_evaluations(:minicex_siti_demam).dup
    evaluation.status = "requested"
    evaluation.save!
    requirement.evidence_records.create!(mini_cex_evaluation: evaluation,
      evidence_date: evaluation.evaluated_at, result: "other")

    assert_equal :in_progress, EvidenceRequirementProgress.new(requirement).call.status
    assert_equal 0, EvidenceRequirementProgress.new(requirement).call.record_count
  end

  private

  def verified_logbook(user: users(:siti))
    log = ActivityLog.create!(user: user, title: "Aktivitas terverifikasi", category: "klinis",
      activity_type: "Observasi", activity_date: Date.current)
    log.verify!(by: users(:budi))
    log
  end
end
