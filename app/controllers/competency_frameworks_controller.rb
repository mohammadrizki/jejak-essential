# frozen_string_literal: true

class CompetencyFrameworksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_competency_framework, only: %i[show edit update destroy new_version publish_version duplicate]

  def index
    authorize CompetencyFramework
    @competency_frameworks = CompetencyFramework.includes(:study_program, :epa_programs).order(:name)
  end

  def show
    authorize @competency_framework
    @domains = @competency_framework.domains.includes(:children, :competency_milestones)
    @has_draft_for_program = @competency_framework.study_program.framework_versions.exists?(status: "draft")
    @academic_periods = AcademicPeriod.ordered
  end

  def new
    authorize CompetencyFramework
    @competency_framework = CompetencyFramework.new(status: "draft")
    load_study_programs
  end

  def create
    authorize CompetencyFramework
    @competency_framework = CompetencyFramework.new(competency_framework_params)

    if @competency_framework.save
      redirect_to competency_framework_path(@competency_framework), notice: "Peta kompetensi ditambahkan."
    else
      load_study_programs
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @competency_framework
    load_study_programs
  end

  def update
    authorize @competency_framework
    if @competency_framework.update(competency_framework_params)
      redirect_to competency_framework_path(@competency_framework), notice: "Peta kompetensi diperbarui."
    else
      load_study_programs
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @competency_framework
    if @competency_framework.destroy
      redirect_to competency_frameworks_path, notice: "Peta kompetensi dihapus.", status: :see_other
    else
      redirect_to competency_framework_path(@competency_framework), status: :see_other,
                  alert: "Peta kompetensi “#{@competency_framework.name}” tidak dapat dihapus: #{@competency_framework.errors.full_messages.to_sentence}."
    end
  end

  def new_version
    authorize @competency_framework, :update?
    if @competency_framework.study_program.framework_versions.exists?(status: "draft")
      return redirect_to @competency_framework, alert: "Selesaikan atau hapus versi draf yang sudah ada terlebih dahulu."
    end

    draft = nil
    ActiveRecord::Base.transaction do
      draft = @competency_framework.study_program.framework_versions.create!(
        name: @competency_framework.name, description: @competency_framework.description,
        education_stage: @competency_framework.education_stage,
        version: (@competency_framework.study_program.framework_versions.pluck(:version).filter_map { |v| Integer(v, exception: false) }.max || 0) + 1,
        status: "draft"
      )
      item_map = {}
      indicator_map = {}
      source_items = @competency_framework.competency_items.to_a
      pending = @competency_framework.competency_items.includes(:competency_indicators, :competency_milestones, :evidence_requirements).to_a
      until pending.empty?
        ready, pending = pending.partition { |item| item.parent_id.nil? || item_map.key?(item.parent_id) }
        raise ActiveRecord::RecordInvalid.new(draft) if ready.empty?

        ready.each do |old_item|
          copy = draft.competency_items.create!(
            code: old_item.code, title: old_item.title, description: old_item.description,
            parent: item_map[old_item.parent_id], position: old_item.position,
            expected_evidence_text: old_item.expected_evidence_text,
            expected_evidence_types: old_item.expected_evidence_types
          )
          item_map[old_item.id] = copy
          old_item.competency_indicators.each do |indicator|
            indicator_map[indicator.id] = copy.competency_indicators.create!(
              indicator.attributes.except("id", "competency_item_id", "created_at", "updated_at")
                .merge("performance_level" => indicator.performance_level.presence || "Standar kinerja perlu ditetapkan program studi sebelum framework diterbitkan.")
            )
          end
          old_item.competency_milestones.each do |milestone|
            copy.competency_milestones.create!(milestone.attributes.except("id", "competency_item_id", "created_at", "updated_at"))
          end
        end
      end
      CompetencyProgression.where(source_competency_id: @competency_framework.competency_items.select(:id)).each do |progression|
        CompetencyProgression.create!(
          source_competency: item_map.fetch(progression.source_competency_id),
          target_competency: item_map.fetch(progression.target_competency_id),
          relationship_type: progression.relationship_type, notes: progression.notes
        )
      end
      epa_map = {}
      @competency_framework.epas.each do |old_epa|
        epa_attributes = old_epa.attributes.except("id", "competency_framework_id", "created_at", "updated_at").merge("status" => "draft")
        if old_epa.code.start_with?("LEGACY-")
          old_competency_id = old_epa.code.delete_prefix("LEGACY-").to_i
          epa_attributes["code"] = "LEGACY-#{item_map.fetch(old_competency_id).id}" if item_map.key?(old_competency_id)
        end
        copy = draft.epas.create!(epa_attributes)
        old_epa.epa_competencies.each do |mapping|
          copy.epa_competencies.create!(
            competency_item: item_map.fetch(mapping.competency_item_id),
            competency_indicator: mapping.competency_indicator_id && indicator_map[mapping.competency_indicator_id],
            contribution: mapping.contribution, importance_weight: mapping.importance_weight, notes: mapping.notes,
            ksa_dimension: mapping.ksa_dimension, is_prerequisite: mapping.is_prerequisite,
            minimum_attainment_level: mapping.minimum_attainment_level, is_critical: mapping.is_critical
          )
        end
        old_epa.epa_milestones.each do |milestone|
          copy.epa_milestones.create!(milestone.attributes.except("id", "epa_id", "created_at", "updated_at"))
        end
        epa_map[old_epa.id] = copy
      end
      manual_requirements = EvidenceRequirement.where(origin: "manual", competency_item_id: source_items.map(&:id))
        .or(EvidenceRequirement.where(origin: "manual", epa_id: @competency_framework.epas.select(:id))).distinct
      manual_requirements.each do |requirement|
        requirement_copy = requirement.attributes.except("id", "blueprint_item_id", "created_at", "updated_at")
        requirement_copy["competency_item_id"] = item_map[requirement.competency_item_id]&.id if requirement.competency_item_id
        requirement_copy["competency_indicator_id"] = indicator_map[requirement.competency_indicator_id]&.id if requirement.competency_indicator_id
        requirement_copy["epa_id"] = epa_map[requirement.epa_id]&.id if requirement.epa_id
        EvidenceRequirement.create!(requirement_copy)
      end
    end
    redirect_to competency_framework_path(draft), notice: "Draf framework versi #{draft.version} dibuat; versi terbit lama tetap tersimpan."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @competency_framework, alert: e.record.errors.full_messages.to_sentence
  end

  def duplicate
    authorize @competency_framework, :show?
    authorize CompetencyFramework, :create?
    load_duplicate_form
    return unless request.post?

    target_program = StudyProgram.find(params.require(:study_program_id))
    duplicate = CompetencyFrameworkDuplicator.new(
      source_framework: @competency_framework,
      study_program: target_program,
      name: params.require(:name),
      copy_manual_requirements: params[:copy_manual_requirements]
    ).call
    redirect_to duplicate, notice: "Framework diduplikasi sebagai draf independen versi #{duplicate.version}."
  rescue ActiveRecord::RecordInvalid => e
    @duplicate_errors = e.record.errors.full_messages
    load_duplicate_form
    render :duplicate, status: :unprocessable_entity
  end

  def publish_version
    authorize @competency_framework, :update?
    return redirect_to @competency_framework, alert: "Hanya framework draf yang dapat diterbitkan." unless @competency_framework.status == "draft"

    @competency_framework.publish!
    redirect_to @competency_framework, notice: "Framework versi #{@competency_framework.version} diterbitkan; versi sebelumnya diarsipkan."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @competency_framework, alert: e.record.errors.full_messages.to_sentence
  end

  private

  def set_competency_framework
    @competency_framework = CompetencyFramework.find(params[:id])
  end

  def competency_framework_params
    params.require(:competency_framework).permit(:name, :description, :study_program_id, :version, :education_stage, :effective_date, :status)
  end

  def load_study_programs
    @study_programs = StudyProgram.ordered
  end

  def load_duplicate_form
    @study_programs = StudyProgram.ordered
    @domains = @competency_framework.domains.includes(:competency_indicators, children: :competency_indicators)
  end
end
