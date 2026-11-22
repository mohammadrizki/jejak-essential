require "test_helper"

class CompetencyFrameworkDuplicatorTest < ActiveSupport::TestCase
  test "CanMEDS template creates an independent seven-domain sarjana draft with provenance" do
    template = CompetencyFrameworkTemplate.find_by_key("canmeds_undergraduate_v1")

    copy = CompetencyFrameworkDuplicator.new(
      template: template, study_program: study_programs(:sarjana_kedokteran), name: "CanMEDS Lokal"
    ).call

    assert_equal "draft", copy.status
    assert_equal "sarjana", copy.education_stage
    assert_equal 7, copy.domains.count
    assert copy.competency_indicators.exists?
    assert_equal "built_in_template", copy.provenance.fetch("kind")
    assert_equal "2015", copy.provenance.fetch("source_version").to_s
    assert_equal 0, copy.epas.count
    assert_equal 0, copy.blueprint_versions.count
  end

  test "framework duplication remaps its hierarchy and optionally copies manual evidence rules only" do
    source = competency_frameworks(:skdi_ringkas)
    source_item = competency_items(:sub_anamnesis)
    indicator = source_item.competency_indicators.create!(
      code: "SUB-ANAMNESIS-PAIN-HISTORY", description: "Menggali riwayat nyeri secara terstruktur",
      performance_level: "Mandiri dengan supervisi"
    )
    requirement = EvidenceRequirement.create!(
      origin: "manual", competency_item: source_item, competency_indicator: indicator,
      source_type: "logbook", required_count: 2,
      fulfillment_rule: { "minimum_distinct_opportunities" => 2, "critical" => true }
    )
    EvidenceRecord.create!(evidence_requirement: requirement, activity_log: activity_logs(:jaga_igd),
                           evidence_date: Date.current, result: "pass")

    copy = CompetencyFrameworkDuplicator.new(
      source_framework: source, study_program: study_programs(:profesi_dokter),
      name: "Salinan Independen", copy_manual_requirements: true
    ).call

    copied_item = copy.competency_items.find_by!(code: source_item.code)
    copied_indicator = copied_item.competency_indicators.find_by!(code: indicator.code)
    copied_requirement = copied_indicator.evidence_requirements.find_by!(source_type: "logbook")

    refute_equal source_item.id, copied_item.id
    refute_equal indicator.id, copied_indicator.id
    assert_equal copied_item.id, copied_indicator.competency_item_id
    assert_equal copied_item.id, copied_requirement.competency_item_id
    assert_equal copied_indicator.id, copied_requirement.competency_indicator_id
    assert_equal 2, copied_requirement.required_count
    assert copied_requirement.fulfillment_rule.fetch("critical")
    assert_empty copied_requirement.evidence_records
    assert_equal source.id, copy.provenance.fetch("source_framework_id")
    assert_equal "draft", copy.status
  end

  test "framework duplication omits manual evidence rules unless explicitly selected" do
    source = competency_frameworks(:skdi_ringkas)
    item = competency_items(:sub_anamnesis)
    indicator = item.competency_indicators.create!(code: "SUB-ANAMNESIS-EXAM", description: "Melakukan pemeriksaan", performance_level: "Dengan supervisi")
    EvidenceRequirement.create!(origin: "manual", competency_item: item, competency_indicator: indicator,
                                source_type: "assessment", required_count: 1)

    copy = CompetencyFrameworkDuplicator.new(
      source_framework: source, study_program: study_programs(:profesi_dokter), name: "Tanpa Syarat"
    ).call

    assert_empty copy.competency_items.flat_map(&:evidence_requirements)
  end
end
