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

  test "a requested WPBA observation does not count as valid evidence" do
    item = competency_items(:sub_anamnesis)
    requirement = EvidenceRequirement.create!(origin: "manual", competency_item: item,
      source_type: "wpba", required_count: 1)
    evaluation = mini_cex_evaluations(:minicex_siti_demam)
    evaluation.update!(status: "requested")
    requirement.evidence_records.create!(mini_cex_evaluation: evaluation,
      evidence_date: evaluation.evaluated_at, result: "other")

    assert_equal :in_progress, EvidenceRequirementProgress.new(requirement).call.status
    assert_equal 0, EvidenceRequirementProgress.new(requirement).call.record_count
  end

  private

  def verified_logbook
    log = ActivityLog.create!(user: users(:siti), title: "Aktivitas terverifikasi", category: "klinis",
      activity_type: "Observasi", activity_date: Date.current)
    log.verify!(by: users(:budi))
    log
  end
end
