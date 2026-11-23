# frozen_string_literal: true

class EvidenceRequirementsController < ApplicationController
  before_action :authenticate_user!
  def index
    authorize CompetencyFramework, :create?
    scope = EvidenceRequirement.all
    unless current_user.has_role?("superadmin")
      program_ids = StudyProgram.ordered.select { |program| current_user.has_permission?("curriculum.manage", study_program: program) }.map(&:id)
      # Curriculum managers can inspect the built-in demonstration alongside
      # their own programs. It remains read-only through the record policies.
      program_ids |= StudyProgram.showcases.pluck(:id)
      framework_ids = CompetencyFramework.where(study_program_id: program_ids).select(:id)
      item_ids = CompetencyItem.where(competency_framework_id: framework_ids).select(:id)
      epa_ids = Epa.where(competency_framework_id: framework_ids).select(:id)
      blueprint_item_ids = BlueprintItem.joins(:blueprint_version)
        .where(blueprint_versions: { assessment_blueprint_id: AssessmentBlueprint.where(study_program_id: program_ids).select(:id) })
        .select(:id)
      scope = EvidenceRequirement.where(competency_item_id: item_ids)
        .or(EvidenceRequirement.where(epa_id: epa_ids))
        .or(EvidenceRequirement.where(blueprint_item_id: blueprint_item_ids))
    end
    @requirements = scope.includes(:competency_item, :competency_indicator, :epa,
      blueprint_item: { blueprint_version: :assessment_blueprint }).order(:origin, :id)
  end

  before_action :set_requirement_context, only: %i[edit update destroy]

  def create
    if params[:blueprint_item_id].present?
      @blueprint_item = BlueprintItem.find(params[:blueprint_item_id])
      authorize @blueprint_item.blueprint_version.assessment_blueprint, :update?
      return redirect_to assessment_blueprint_path(@blueprint_item.blueprint_version.assessment_blueprint), alert: "Syarat bukti blueprint hanya dapat diubah pada versi draf." unless @blueprint_item.blueprint_version.status == "draft"
      origin = "blueprint"
      source_id = @blueprint_item.id
    else
      @framework = CompetencyFramework.find(params[:competency_framework_id])
      authorize @framework, :update?
      origin = "manual"
      source_id = nil
    end

    attributes = requirement_params.to_h
    framework = @blueprint_item&.blueprint_version&.competency_framework || @framework
    if attributes["competency_item_id"].present?
      attributes["competency_item_id"] = framework.competency_items.find_by(id: attributes["competency_item_id"])&.id
    end
    if attributes["competency_indicator_id"].present?
      indicator = framework.competency_indicators.find_by(id: attributes["competency_indicator_id"])
      attributes["competency_indicator_id"] = indicator&.id
      attributes["competency_item_id"] = indicator.competency_item_id if indicator
    end
    if attributes["epa_id"].present?
      attributes["epa_id"] = framework.epas.find_by(id: attributes["epa_id"])&.id
    end
    requirement = EvidenceRequirement.new(attributes.merge(origin: origin, blueprint_item_id: source_id))
    if requirement.save
      redirect_to(@blueprint_item ? assessment_blueprint_path(@blueprint_item.blueprint_version.assessment_blueprint) : competency_framework_path(@framework),
        notice: "Syarat bukti ditambahkan.")
    else
      redirect_to(@blueprint_item ? assessment_blueprint_path(@blueprint_item.blueprint_version.assessment_blueprint) : competency_framework_path(@framework),
        alert: requirement.errors.full_messages.to_sentence)
    end
  end

  def edit
  end

  def update
    if @requirement.update(requirement_update_params)
      redirect_to requirement_parent_path, notice: "Syarat bukti diperbarui."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @requirement.destroy
      redirect_to requirement_parent_path, notice: "Syarat bukti dihapus.", status: :see_other
    else
      redirect_to requirement_parent_path, alert: "Syarat bukti tidak dapat dihapus: #{@requirement.errors.full_messages.to_sentence}.", status: :see_other
    end
  end

  private

  def requirement_params
    params.require(:evidence_requirement).permit(:competency_item_id, :competency_indicator_id, :epa_id,
      :assessment_method_id, :source_type, :required_count, :due_stage, :is_mandatory,
      fulfillment_rule: [ :require_validation, :minimum_valid_evidence, :minimum_pass,
        :minimum_distinct_cases, :minimum_distinct_assessors, :minimum_distinct_opportunities,
        :minimum_distinct_dates, :minimum_span_days,
        :independence_group, :critical, :additional_criteria, { valid_results: [] } ])
  end

  def requirement_update_params
    params.require(:evidence_requirement).permit(:source_type, :required_count,
      fulfillment_rule: [ :require_validation, :minimum_valid_evidence, :minimum_pass,
        :minimum_distinct_cases, :minimum_distinct_assessors, :minimum_distinct_opportunities,
        :minimum_distinct_dates, :minimum_span_days,
        :independence_group, :critical, :additional_criteria, { valid_results: [] } ])
  end

  def set_requirement_context
    if params[:blueprint_item_id].present?
      @blueprint_item = BlueprintItem.find(params[:blueprint_item_id])
      @assessment_blueprint = @blueprint_item.blueprint_version.assessment_blueprint
      authorize @assessment_blueprint, :update?
      unless @blueprint_item.blueprint_version.status == "draft"
        return redirect_to assessment_blueprint_path(@assessment_blueprint), alert: "Syarat bukti hanya dapat diubah pada versi draf."
      end
      @requirement = @blueprint_item.evidence_requirements.find(params[:id])
    else
      @framework = CompetencyFramework.find(params[:competency_framework_id])
      authorize @framework, :update?
      unless @framework.status == "draft"
        return redirect_to competency_framework_path(@framework), alert: "Syarat bukti hanya dapat diubah pada framework draf."
      end
      item_ids = @framework.competency_items.select(:id)
      epa_ids = @framework.epas.select(:id)
      @requirement = EvidenceRequirement.where(origin: "manual")
        .where(competency_item_id: item_ids)
        .or(EvidenceRequirement.where(origin: "manual", epa_id: epa_ids))
        .find(params[:id])
    end
  end

  def requirement_parent_path
    if @blueprint_item
      assessment_blueprint_path(@assessment_blueprint)
    else
      competency_framework_path(@framework)
    end
  end
end
