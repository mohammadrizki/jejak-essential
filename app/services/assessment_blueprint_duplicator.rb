# frozen_string_literal: true

# Copies blueprint configuration to another program and remaps every
# competency, indicator, and EPA by stable code into its published framework.
# It never copies assessment results, evidence records, or student decisions.
class AssessmentBlueprintDuplicator
  class IncompatibleFramework < StandardError; end

  def initialize(source_blueprint:, target_program:, name:)
    @source_blueprint = source_blueprint
    @target_program = target_program
    @name = name.to_s.strip
    @source_version = source_blueprint.current_version
    @source_framework = @source_version&.competency_framework
    @target_framework = target_program.framework_versions.find_by(status: "published")
  end

  def call
    validate_source_and_target!

    AssessmentBlueprint.transaction do
      raise IncompatibleFramework, "Program studi tujuan sudah memiliki Blueprint Asesmen." if @target_program.assessment_blueprint.present?

      duplicate = AssessmentBlueprint.new(
        study_program: @target_program,
        name: @name,
        description: @source_blueprint.description,
        learning_outcomes: @source_blueprint.learning_outcomes
      )
      duplicate.initial_competency_framework_id = @target_framework.id
      duplicate.skip_initial_outline = true
      duplicate.save!

      version = duplicate.blueprint_versions.find_by!(version: 1)
      version.update!(change_notes: "Draf salinan dari #{@source_blueprint.name} versi #{@source_version.version}; dipetakan ulang ke #{@target_framework.name} versi #{@target_framework.version}.")
      copy_assessment_blueprint_mappings!(duplicate)
      copy_blueprint_items!(version)
      duplicate
    end
  end

  private

  def validate_source_and_target!
    raise IncompatibleFramework, "Blueprint sumber belum memiliki versi yang dapat disalin." if @source_version.blank? || @source_framework.blank?
    raise IncompatibleFramework, "Peta Kompetensi tujuan harus sudah diterbitkan." if @target_framework.blank?
    raise IncompatibleFramework, "Nama Blueprint baru wajib diisi." if @name.blank?

    @source_version.blueprint_items.includes(blueprint_item_competencies: %i[competency_item competency_indicator],
      blueprint_item_epas: :epa, evidence_requirements: %i[competency_item competency_indicator epa]).each do |item|
      item.blueprint_item_competencies.each { |mapping| target_mapping!(mapping) }
      item.blueprint_item_epas.each { |mapping| target_epa!(mapping.epa) }
      item.evidence_requirements.where(status: "active").each { |requirement| target_requirement!(requirement) }
    end
    @source_blueprint.assessment_blueprint_mappings.includes(:competency_item).each do |mapping|
      target_item!(mapping.competency_item)
    end
  end

  def copy_assessment_blueprint_mappings!(duplicate)
    @source_blueprint.assessment_blueprint_mappings.includes(:competency_item).each do |mapping|
      duplicate.assessment_blueprint_mappings.create!(
        competency_item: target_item!(mapping.competency_item), weight: mapping.weight
      )
    end
  end

  def copy_blueprint_items!(version)
    @source_version.blueprint_items.includes(:assessment_method,
      blueprint_item_competencies: %i[competency_item competency_indicator],
      blueprint_item_epas: %i[epa supervision_level], evidence_requirements: %i[competency_item competency_indicator epa]).each do |source_item|
      item = version.blueprint_items.create!(
        source_item.attributes.except("id", "blueprint_version_id", "created_at", "updated_at")
      )

      source_item.blueprint_item_competencies.each do |mapping|
        target_item = target_item!(mapping.competency_item)
        target_indicator = mapping.competency_indicator && target_indicator!(mapping.competency_indicator, target_item)
        item.blueprint_item_competencies.create!(
          mapping.attributes.except("id", "blueprint_item_id", "competency_item_id", "competency_indicator_id", "created_at", "updated_at")
            .merge(competency_item: target_item, competency_indicator: target_indicator)
        )
      end

      source_item.blueprint_item_epas.each do |mapping|
        item.blueprint_item_epas.create!(
          mapping.attributes.except("id", "blueprint_item_id", "epa_id", "created_at", "updated_at")
            .merge(epa: target_epa!(mapping.epa))
        )
      end

      source_item.evidence_requirements.where(status: "active").each do |requirement|
        item.evidence_requirements.create!(copy_requirement_attributes(requirement, item))
      end
    end
  end

  def copy_requirement_attributes(requirement, blueprint_item)
    attributes = requirement.attributes.except("id", "blueprint_item_id", "competency_item_id", "competency_indicator_id", "epa_id", "created_at", "updated_at")
    attributes.merge(
      blueprint_item: blueprint_item,
      competency_item: requirement.competency_item && target_item!(requirement.competency_item),
      competency_indicator: requirement.competency_indicator && target_indicator!(requirement.competency_indicator),
      epa: requirement.epa && target_epa!(requirement.epa)
    )
  end

  def target_mapping!(mapping)
    item = target_item!(mapping.competency_item)
    target_indicator!(mapping.competency_indicator, item) if mapping.competency_indicator
  end

  def target_requirement!(requirement)
    target_item!(requirement.competency_item) if requirement.competency_item
    target_indicator!(requirement.competency_indicator) if requirement.competency_indicator
    target_epa!(requirement.epa) if requirement.epa
  end

  def target_item!(source_item)
    @target_framework.competency_items.find_by(code: source_item.code) ||
      raise(IncompatibleFramework, "Kompetensi berkode #{source_item.code} tidak tersedia pada Peta Kompetensi tujuan.")
  end

  def target_indicator!(source_indicator, target_item = nil)
    target_item ||= target_item!(source_indicator.competency_item)
    indicator = @target_framework.competency_indicators.find_by(code: source_indicator.code)
    return indicator if indicator&.competency_item_id == target_item.id

    raise IncompatibleFramework, "Indikator berkode #{source_indicator.code} tidak cocok pada Peta Kompetensi tujuan."
  end

  def target_epa!(source_epa)
    @target_framework.epas.find_by(code: source_epa.code) ||
      raise(IncompatibleFramework, "EPA berkode #{source_epa.code} tidak tersedia pada Peta Kompetensi tujuan.")
  end
end
