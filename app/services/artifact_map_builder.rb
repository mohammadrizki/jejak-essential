# frozen_string_literal: true

# Builds the program-level list of expected artifacts from the current
# competency framework, blueprint version, and active manual requirements.
# It never reads learner evidence or stores a second artifact master.
class ArtifactMapBuilder
  RequirementEntry = Data.define(:requirement, :targets, :configuration)
  BlueprintEntry = Data.define(:blueprint_item, :targets, :requirements)
  ManualEntry = Data.define(:requirement, :targets, :configuration)
  Result = Data.define(:blueprint_entries, :manual_entries)

  def initialize(framework:, blueprint_version:)
    @framework = framework
    @blueprint_version = blueprint_version
  end

  def call
    Result.new(blueprint_entries: blueprint_entries, manual_entries: manual_entries)
  end

  private

  def blueprint_entries
    return [] unless @blueprint_version

    @blueprint_version.blueprint_items
      .includes(:assessment_method, { evidence_requirements: :versions },
        blueprint_item_competencies: [ :competency_item, { competency_indicator: { competency_item: { parent: :parent } } } ],
        blueprint_item_epas: :epa)
      .order(:position, :code).map do |item|
        targets = blueprint_targets(item)
        requirements = active_requirements(item.evidence_requirements).map do |requirement|
          requirement_entry(requirement, fallback_targets: targets)
        end
        BlueprintEntry.new(blueprint_item: item, targets: targets, requirements: requirements)
      end
  end

  def manual_entries
    return [] unless @framework

    item_ids = @framework.competency_items.select(:id)
    indicator_ids = @framework.competency_indicators.select(:id)
    epa_ids = @framework.epas.select(:id)
    requirements = EvidenceRequirement.where(origin: "manual", status: "active")
      .where(competency_item_id: item_ids)
      .or(EvidenceRequirement.where(origin: "manual", status: "active", competency_indicator_id: indicator_ids))
      .or(EvidenceRequirement.where(origin: "manual", status: "active", epa_id: epa_ids))
      .includes({ competency_item: { parent: :parent } },
        { competency_indicator: { competency_item: { parent: :parent } } }, :epa, :versions)
      .order(:id)

    active_requirements(requirements).reject { |requirement| represented_by_blueprint?(requirement) }.map do |requirement|
      entry = requirement_entry(requirement)
      ManualEntry.new(requirement: requirement, targets: entry.targets, configuration: entry.configuration)
    end
  end

  def represented_by_blueprint?(requirement)
    return false unless @blueprint_version

    blueprint_requirement_signatures.include?(requirement_signature(requirement))
  end

  def blueprint_requirement_signatures
    @blueprint_requirement_signatures ||= begin
      requirements = @blueprint_version.blueprint_items.includes(evidence_requirements: :versions)
        .flat_map(&:evidence_requirements)
      active_requirements(requirements).map { |requirement| requirement_signature(requirement) }
    end
  end

  def requirement_signature(requirement)
    target = requirement.competency_indicator || requirement.competency_item || requirement.epa
    [requirement.assessment_method_id, target&.class&.name, target&.id]
  end

  def active_requirements(requirements)
    requirements.select do |requirement|
      effective_configuration(requirement).fetch("status", requirement.status) == "active"
    end
  end

  def effective_configuration(requirement)
    version = if requirement.association(:versions).loaded?
      requirement.versions.max_by(&:version)
    else
      requirement.current_version
    end
    version&.configuration || requirement.configuration_snapshot
  end

  def requirement_entry(requirement, fallback_targets: [])
    targets = manual_targets(requirement)
    targets = fallback_targets if targets.empty?
    RequirementEntry.new(requirement: requirement, targets: targets,
      configuration: effective_configuration(requirement))
  end

  def blueprint_targets(item)
    mappings = item.blueprint_item_competencies.map do |mapping|
      if mapping.competency_indicator
        indicator_target(mapping.competency_indicator)
      else
        item_target(mapping.competency_item)
      end
    end
    epa_targets = item.blueprint_item_epas.map { |mapping| epa_target(mapping.epa) }
    (mappings + epa_targets).compact.uniq
  end

  def manual_targets(requirement)
    targets = []
    targets << indicator_target(requirement.competency_indicator) if requirement.competency_indicator
    targets << item_target(requirement.competency_item) if requirement.competency_item
    targets << epa_target(requirement.epa) if requirement.epa
    targets.compact.uniq
  end

  def indicator_target(indicator)
    item = indicator.competency_item
    [hierarchy_label(item), "#{indicator.code} · #{indicator.description}"].compact.join(" / ")
  end

  def item_target(item)
    return if item.blank?

    [hierarchy_label(item), "#{item.code} · #{item.title}"].compact.uniq.join(" / ")
  end

  def hierarchy_label(item)
    ancestors = []
    node = item
    while node
      ancestors.unshift(node.title)
      node = node.parent
    end
    ancestors.join(" / ")
  end

  def epa_target(epa)
    "#{epa.code} · #{epa.title} (EPA)" if epa
  end
end
