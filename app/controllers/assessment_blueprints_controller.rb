# frozen_string_literal: true

class AssessmentBlueprintsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_assessment_blueprint, only: %i[show edit update destroy new_version publish_version]

  def index
    authorize AssessmentBlueprint
    @assessment_blueprints = AssessmentBlueprint.includes(:study_program).order(:name)
  end

  def show
    authorize @assessment_blueprint
    framework = @assessment_blueprint.study_program.peta_kompetensi
    @available_competency_items = if framework
      framework.competency_items.where.not(id: @assessment_blueprint.competency_items.select(:id)).order(:position)
    else
      CompetencyItem.none
    end
    @blueprint_version = @assessment_blueprint.draft_version || @assessment_blueprint.current_version
    @assessment_methods = AssessmentMethod.where(is_active: true).order(:name)
    @available_epas = framework&.epas&.where(status: "published") || Epa.none
  end

  def new
    authorize AssessmentBlueprint
    @assessment_blueprint = AssessmentBlueprint.new
    load_study_programs
  end

  def create
    authorize AssessmentBlueprint
    @assessment_blueprint = AssessmentBlueprint.new(assessment_blueprint_params)

    if @assessment_blueprint.save
      redirect_to assessment_blueprint_path(@assessment_blueprint), notice: "Blueprint asesmen dibuat sebagai draf. Tambahkan komponennya sebelum menerbitkan."
    else
      load_study_programs
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @assessment_blueprint
    load_study_programs
  end

  def update
    authorize @assessment_blueprint
    if @assessment_blueprint.update(assessment_blueprint_params)
      redirect_to assessment_blueprints_path, notice: "Blueprint asesmen diperbarui."
    else
      load_study_programs
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @assessment_blueprint
    if @assessment_blueprint.destroy
      redirect_to assessment_blueprints_path, notice: "Blueprint asesmen dihapus.", status: :see_other
    else
      redirect_to assessment_blueprint_path(@assessment_blueprint), alert: "Blueprint memiliki versi historis dan tidak dapat dihapus: #{@assessment_blueprint.errors.full_messages.to_sentence}."
    end
  end

  def new_version
    authorize @assessment_blueprint, :update?
    framework = @assessment_blueprint.study_program.peta_kompetensi
    return redirect_to @assessment_blueprint, alert: "Program studi belum memiliki Peta Kompetensi." if framework.blank?
    return redirect_to @assessment_blueprint, alert: "Selesaikan atau arsipkan draf yang sedang ada terlebih dahulu." if @assessment_blueprint.draft_version

    version = nil
    ActiveRecord::Base.transaction do
      version = @assessment_blueprint.blueprint_versions.create!(
        competency_framework: framework,
        version: (@assessment_blueprint.blueprint_versions.maximum(:version) || 0) + 1,
        status: "draft", change_notes: params[:change_notes]
      )
      source = @assessment_blueprint.current_version
      source&.blueprint_items&.includes(:blueprint_item_competencies, :blueprint_item_epas)&.each do |old_item|
        copy = version.blueprint_items.create!(old_item.attributes.except("id", "blueprint_version_id", "created_at", "updated_at"))
        old_item.blueprint_item_competencies.each do |mapping|
          copy.blueprint_item_competencies.create!(mapping.attributes.except("id", "blueprint_item_id", "created_at", "updated_at"))
        end
        old_item.blueprint_item_epas.each do |mapping|
          copy.blueprint_item_epas.create!(mapping.attributes.except("id", "blueprint_item_id", "created_at", "updated_at"))
        end
        old_item.evidence_requirements.each do |requirement|
          copy.evidence_requirements.create!(requirement.attributes.except("id", "blueprint_item_id", "created_at", "updated_at"))
        end
      end
    end
    redirect_to @assessment_blueprint, notice: "Versi draf #{version.version} dibuat. Versi terbit tetap tersimpan sebagai riwayat."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @assessment_blueprint, alert: e.record.errors.full_messages.to_sentence
  end

  def publish_version
    authorize @assessment_blueprint, :update?
    version = @assessment_blueprint.draft_version
    return redirect_to @assessment_blueprint, alert: "Tidak ada versi draf untuk diterbitkan." if version.blank?

    version.publish!
    redirect_to @assessment_blueprint, notice: "Blueprint versi #{version.version} diterbitkan; versi sebelumnya diarsipkan."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @assessment_blueprint, alert: e.record.errors.full_messages.to_sentence
  end

  private

  def set_assessment_blueprint
    @assessment_blueprint = AssessmentBlueprint.find(params[:id])
  end

  # learning_outcomes ditulis sebagai baris teks (satu capaian per baris) —
  # peta bobot kompetensi sendiri sudah pindah ke AssessmentBlueprintMapping
  # (relasi FK, dikelola lewat AssessmentBlueprintMappingsController),
  # menggantikan competency_mapping JSONB label-bebas yang lama.
  def assessment_blueprint_params
    outcomes = params.dig(:assessment_blueprint, :learning_outcomes_text).to_s
      .split("\n").map(&:strip).reject(&:blank?)

    params.require(:assessment_blueprint).permit(:name, :description, :study_program_id).merge(learning_outcomes: outcomes)
  end

  def load_study_programs
    @study_programs = StudyProgram.ordered
  end
end
