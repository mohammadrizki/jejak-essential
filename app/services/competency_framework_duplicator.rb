# frozen_string_literal: true

# Creates a new, independent draft from either a framework or a built-in
# template. Only configuration is copied; student results and blueprint
# versions stay attached to their original records.
class CompetencyFrameworkDuplicator
  def initialize(study_program:, name:, source_framework: nil, template: nil, copy_manual_requirements: false)
    raise ArgumentError, "Pilih tepat satu sumber framework" if source_framework.present? == template.present?

    @study_program = study_program
    @name = name
    @source_framework = source_framework
    @template = template
    @copy_manual_requirements = ActiveModel::Type::Boolean.new.cast(copy_manual_requirements)
  end

  def call
    CompetencyFramework.transaction do
      framework = @study_program.framework_versions.create!(
        name: @name,
        description: source_description,
        education_stage: destination_stage,
        status: "draft",
        provenance: provenance
      )

      item_map, indicator_map, epa_map = if @template
        copy_template_contents(framework)
      else
        copy_framework_contents(framework)
      end

      copy_manual_requirements(framework, item_map, indicator_map, epa_map) if @copy_manual_requirements && @source_framework
      framework
    end
  end

  private

  def source_description
    @source_framework&.description || @template&.description
  end

  def destination_stage
    @study_program.level
  end

  def provenance
    if @template
      {
        "kind" => "built_in_template",
        "template_key" => @template.key,
        "template_version" => @template.template_version,
        "source_name" => @template.source_name,
        "source_version" => @template.source_version,
        "attribution" => @template.attribution,
        "copied_at" => Time.current.iso8601
      }
    else
      {
        "kind" => "framework_copy",
        "source_framework_id" => @source_framework.id,
        "source_framework_name" => @source_framework.name,
        "source_framework_version" => @source_framework.version,
        "source_framework_status" => @source_framework.status,
        "inherited_provenance" => @source_framework.provenance,
        "copied_at" => Time.current.iso8601
      }
    end
  end

  def copy_template_contents(framework)
    item_map = {}
    indicator_map = {}
    @template.domains.each do |domain_data|
      domain = create_item(framework, domain_data, nil)
      item_map[domain_data.fetch("code")] = domain
      copy_template_indicators(domain, domain_data.fetch("indicators", []), indicator_map)

      domain_data.fetch("subcompetencies", []).each do |sub_data|
        sub = create_item(framework, sub_data, domain)
        item_map[sub_data.fetch("code")] = sub
        copy_template_indicators(sub, sub_data.fetch("indicators", []), indicator_map)
      end
    end
    [ item_map, indicator_map, {} ]
  end

  def create_item(framework, data, parent)
    framework.competency_items.create!(
      code: data.fetch("code"), title: data.fetch("title"),
      description: data["description"], parent: parent
    )
  end

  def review_standard
    "Standar kinerja perlu ditetapkan program studi sebelum framework diterbitkan."
  end

  def copy_template_indicators(item, indicators, indicator_map)
    indicators.each do |data|
      indicator = item.competency_indicators.create!(
        code: data.fetch("code"), description: data.fetch("description"),
        performance_level: data["performance_level"]
      )
      indicator_map[data.fetch("code")] = indicator
    end
  end

  def copy_framework_contents(framework)
    item_map = {}
    indicator_map = {}
    pending = @source_framework.competency_items.includes(:competency_indicators).to_a

    until pending.empty?
      ready, pending = pending.partition { |item| item.parent_id.nil? || item_map.key?(item.parent_id) }
      raise ActiveRecord::RecordInvalid.new(framework) if ready.empty?

      ready.each do |source_item|
        copy = framework.competency_items.create!(
          code: source_item.code, title: source_item.title, description: source_item.description,
          parent: item_map[source_item.parent_id], position: source_item.position,
          expected_evidence_text: source_item.expected_evidence_text,
          expected_evidence_types: source_item.expected_evidence_types
        )
        item_map[source_item.id] = copy
        source_item.competency_indicators.each do |source_indicator|
          indicator = copy.competency_indicators.create!(
            source_indicator.attributes.except("id", "competency_item_id", "created_at", "updated_at")
              .merge("performance_level" => source_indicator.performance_level.presence || review_standard)
          )
          indicator_map[source_indicator.id] = indicator
        end
      end
    end

    copy_progressions(item_map)
    epa_map = copy_epas(framework, item_map, indicator_map)
    [ item_map, indicator_map, epa_map ]
  end

  def copy_progressions(item_map)
    CompetencyProgression.where(source_competency_id: item_map.keys).find_each do |progression|
      target = item_map[progression.target_competency_id]
      next unless target

      CompetencyProgression.create!(
        source_competency: item_map.fetch(progression.source_competency_id),
        target_competency: target,
        relationship_type: progression.relationship_type,
        notes: progression.notes
      )
    end
  end

  def copy_epas(framework, item_map, indicator_map)
    epa_map = {}
    @source_framework.epas.where.not("code LIKE 'LEGACY-%'").find_each do |source_epa|
      copy = framework.epas.create!(
        source_epa.attributes.except("id", "competency_framework_id", "created_at", "updated_at")
          .merge("status" => "draft")
      )
      epa_map[source_epa.id] = copy

      source_epa.epa_competencies.each do |mapping|
        target_item = item_map[mapping.competency_item_id]
        next unless target_item

        copy.epa_competencies.create!(
          competency_item: target_item,
          competency_indicator: indicator_map[mapping.competency_indicator_id],
          contribution: mapping.contribution, importance_weight: mapping.importance_weight, notes: mapping.notes,
          ksa_dimension: mapping.ksa_dimension, is_prerequisite: mapping.is_prerequisite,
          minimum_attainment_level: mapping.minimum_attainment_level, is_critical: mapping.is_critical
        )
      end
      source_epa.epa_milestones.each do |milestone|
        copy.epa_milestones.create!(milestone.attributes.except("id", "epa_id", "created_at", "updated_at"))
      end
    end
    epa_map
  end

  def copy_manual_requirements(framework, item_map, indicator_map, epa_map)
    requirement_scope = EvidenceRequirement.where(origin: "manual")
      .where(competency_item_id: item_map.keys)
      .or(EvidenceRequirement.where(origin: "manual", epa_id: @source_framework.epas.select(:id)))

    requirement_scope.find_each do |source_requirement|
      target_item = item_map[source_requirement.competency_item_id]
      target_indicator = indicator_map[source_requirement.competency_indicator_id]
      target_epa = epa_map[source_requirement.epa_id]
      next if source_requirement.competency_indicator_id.present? && target_indicator.blank?
      next if source_requirement.epa_id.present? && target_epa.blank?

      copy = EvidenceRequirement.new(
        source_requirement.attributes.except("id", "blueprint_item_id", "created_at", "updated_at")
          .merge(
            "competency_item_id" => target_item&.id,
            "competency_indicator_id" => target_indicator&.id,
            "epa_id" => target_epa&.id,
            "origin" => "manual"
          )
      )
      # Invalid legacy configuration is left behind on its source and is not
      # propagated into a new draft.
      copy.save! if copy.valid?
    end
  end
end
