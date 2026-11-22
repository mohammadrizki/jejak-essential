# frozen_string_literal: true

class AssessmentBlueprintsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_assessment_blueprint, only: %i[show edit update destroy new_version publish_version]

  def index
    authorize AssessmentBlueprint
    scope = AssessmentBlueprint.includes(:study_program).order(:name)
    if current_user.has_role?("superadmin")
      @assessment_blueprints = scope
    else
      program_ids = StudyProgram.ordered.select { |program| current_user.has_permission?("curriculum.manage", study_program: program) }.map(&:id)
      @assessment_blueprints = scope.where(study_program_id: program_ids)
    end
  end

  def show
    authorize @assessment_blueprint
    @blueprint_version = @assessment_blueprint.draft_version || @assessment_blueprint.current_version
    framework = @blueprint_version&.competency_framework || @assessment_blueprint.study_program.peta_kompetensi
    @available_competency_items = if framework
      framework.competency_items.where.not(id: @assessment_blueprint.competency_items.select(:id)).order(:position)
    else
      CompetencyItem.none
    end
    @assessment_methods = AssessmentMethod.where(is_active: true).order(:name)
    @available_epas = framework&.epas&.where(status: "published") || Epa.none
  end

  def new
    authorize AssessmentBlueprint
    @assessment_blueprint = AssessmentBlueprint.new
    load_study_programs
    @assessment_blueprint.study_program = preferred_study_program
    load_frameworks
  end

  def create
    authorize AssessmentBlueprint
    load_study_programs
    @assessment_blueprint = AssessmentBlueprint.new(assessment_blueprint_params)
    @assessment_blueprint.study_program = preferred_study_program if @assessment_blueprint.study_program_id.blank?
    if @assessment_blueprint.study_program.blank?
      return redirect_to assessment_blueprints_path, alert: "Tidak ada Program Studi dalam cakupan hak akses Anda."
    end
    unless current_user.has_role?("superadmin") || current_user.has_permission?("curriculum.manage", study_program: @assessment_blueprint.study_program)
      return redirect_to assessment_blueprints_path, alert: "Hak akses kelola kurikulum untuk program studi tujuan diperlukan."
    end
    if @assessment_blueprint.initial_competency_framework_id.blank?
      @assessment_blueprint.errors.add(:initial_competency_framework_id, "pilih Peta Kompetensi yang sudah diterbitkan")
      load_study_programs
      load_frameworks
      return render :new, status: :unprocessable_entity
    end

    if @assessment_blueprint.save
      redirect_to assessment_blueprint_path(@assessment_blueprint), notice: "Blueprint asesmen dibuat sebagai draf. Tambahkan komponennya sebelum menerbitkan."
    else
      load_study_programs
      load_frameworks
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @assessment_blueprint
    load_study_programs
  end

  def update
    authorize @assessment_blueprint
    target_program_id = params.dig(:assessment_blueprint, :study_program_id).presence || @assessment_blueprint.study_program_id
    target_program = StudyProgram.find_by(id: target_program_id)
    unless target_program && (current_user.has_role?("superadmin") || current_user.has_permission?("curriculum.manage", study_program: target_program))
      return redirect_to @assessment_blueprint, alert: "Hak akses kelola kurikulum untuk program studi tujuan diperlukan."
    end

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
    framework = @assessment_blueprint.current_version&.competency_framework || @assessment_blueprint.study_program.peta_kompetensi
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

    params.require(:assessment_blueprint).permit(:name, :description, :study_program_id, :initial_competency_framework_id)
      .merge(learning_outcomes: outcomes)
  end

  def load_study_programs
    @study_programs = if current_user.has_role?("superadmin")
      StudyProgram.ordered
    else
      StudyProgram.ordered.select { |program| current_user.has_permission?("curriculum.manage", study_program: program) }
    end
  end

  def preferred_study_program
    return if @study_programs.blank?

    @study_programs.find { |program| program.id == current_user.study_program_id } || @study_programs.first
  end

  def load_frameworks
    program_ids = @study_programs.map(&:id)
    @competency_framework_options = CompetencyFramework.where(study_program_id: program_ids, status: "published")
      .includes(:study_program).order(:study_program_id, version: :desc).map do |framework|
        ["#{framework.study_program.name} — #{framework.name} (v#{framework.version}, Terbit)", framework.id]
      end
  end
end
