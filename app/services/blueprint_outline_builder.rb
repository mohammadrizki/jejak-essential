# frozen_string_literal: true

# Seeds a draft blueprint with explicit assessment targets from the selected
# framework's active Expected Evidence rules. It never guesses an assessment
# method and does not copy requirements, so manual requirements remain the
# authoritative records and are not double-counted.
class BlueprintOutlineBuilder
  def initialize(version:)
    @version = version
    @framework = version.competency_framework
  end

  def call
    return @version if @version.blueprint_items.exists?

    requirements = EvidenceRequirement.where(origin: "manual", status: "active", assessment_method_id: AssessmentMethod.select(:id))
      .where(competency_item_id: @framework.competency_items.select(:id))
      .or(EvidenceRequirement.where(origin: "manual", status: "active", assessment_method_id: AssessmentMethod.select(:id),
        competency_indicator_id: @framework.competency_indicators.select(:id)))
      .or(EvidenceRequirement.where(origin: "manual", status: "active", assessment_method_id: AssessmentMethod.select(:id),
        epa_id: @framework.epas.select(:id)))
      .includes(:assessment_method, :competency_item, :competency_indicator, :epa, :versions)
      .order(:id)
    requirements = requirements.select { |requirement| active_and_valid?(requirement) }

    entries = requirements.filter_map { |requirement| entry_for(requirement) }
      .group_by { |entry| [entry[:assessment_method].id, entry[:target_type], entry[:target].id] }
      .values.map { |group| group.first.merge(requirements: group.map { |entry| entry[:requirement] }) }
    entries.each_with_index { |entry, index| create_item(entry, index + 1) }
    @version
  end

  private

  def entry_for(requirement)
    target = requirement.competency_indicator || requirement.competency_item || requirement.epa
    return if target.blank?

    { requirement: requirement, target: target, assessment_method: requirement.assessment_method,
      target_type: target.class.name }
  end

  def active_and_valid?(requirement)
    version = requirement.versions.max_by(&:version)
    config = version&.configuration || requirement.configuration_snapshot
    config.fetch("status", requirement.status) == "active"
  end

  def create_item(entry, position)
    target = entry[:target]
    requirement = entry[:requirement]
    item = @version.blueprint_items.create!(
      assessment_method: entry[:assessment_method],
      code: "#{target.code}-#{entry[:assessment_method].code}-#{position}",
      title: "#{target.respond_to?(:title) ? target.title : target.description} — #{entry[:assessment_method].name}",
      assessment_context: "Kerangka awal dari Bukti yang Diharapkan aktif pada Peta Kompetensi #{ @framework.name }.",
      curricular_stage: requirement.due_stage,
      minimum_standard: target.try(:performance_level)
    )

    case target
    when CompetencyIndicator
      item.blueprint_item_competencies.create!(competency_item: target.competency_item, competency_indicator: target)
    when CompetencyItem
      item.blueprint_item_competencies.create!(competency_item: target)
    when Epa
      item.blueprint_item_epas.create!(epa: target, assessment_purpose: "formative")
    end

    entry[:requirements].each do |source|
      attributes = source.attributes.except("id", "blueprint_item_id", "created_at", "updated_at")
      copy = item.evidence_requirements.build(attributes.merge("origin" => "blueprint", "blueprint_item_id" => item.id))
      copy.save! if copy.valid?
    end
  end
end
