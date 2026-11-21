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
    EvidenceRecord.create!(evidence_requirement: first, activity_log: activity_logs(:jaga_igd),
                           evidence_date: Date.current, result: "pass")
    EvidenceRecord.create!(evidence_requirement: second, activity_log: activity_logs(:jaga_igd),
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
    EvidenceRecord.create!(evidence_requirement: requirement, activity_log: activity_logs(:jaga_igd),
                           evidence_date: Date.current, result: "pass")

    assert_equal :fulfilled, EvidenceRequirementProgress.new(requirement).call.status
    assert_empty CompetencyAttainment.where(competency_item: item)
  end
end
