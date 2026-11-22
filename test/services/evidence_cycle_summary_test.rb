require "test_helper"

class EvidenceCycleSummaryTest < ActiveSupport::TestCase
  test "summary compares requirement coverage by evidence dates without applying future requirements retroactively" do
    framework = competency_frameworks(:skdi_ringkas)
    student = users(:siti)
    past = AcademicPeriod.create!(name: "Siklus sebelum syarat", start_date: 2.years.ago.to_date,
      end_date: 1.year.ago.to_date)
    current = academic_periods(:current_period)
    requirement = EvidenceRequirement.create!(origin: "manual", competency_item: competency_items(:sub_anamnesis),
      source_type: "logbook", required_count: 1)

    before_evidence = EvidenceCycleSummary.new(student: student, framework: framework,
      periods: [past, current]).call
    past_cycle, current_cycle = before_evidence
    assert_equal 0, past_cycle.requirement_count, "syarat yang dibuat setelah siklus berakhir tidak boleh dianggap wajib pada siklus lama"
    assert_equal 1, current_cycle.requirement_count
    assert_equal 1, current_cycle.not_started_count
    assert_equal 1, current_cycle.critical_gap_count if requirement.is_mandatory?

    log = ActivityLog.create!(user: student, title: "Kasus terverifikasi", category: "klinis",
      activity_type: "Observasi", activity_date: Date.current)
    log.verify!(by: users(:budi))
    EvidenceRecord.create!(evidence_requirement: requirement, activity_log: log,
      evidence_date: Date.current, result: "pass")

    after_evidence = EvidenceCycleSummary.new(student: student, framework: framework,
      periods: [past, current]).call
    assert_equal 0, after_evidence.first.requirement_count
    assert_equal 1, after_evidence.last.fulfilled_count
    assert_empty CompetencyAttainment.where(student: student), "kecukupan lintas siklus bukan keputusan capaian"
  end
end
