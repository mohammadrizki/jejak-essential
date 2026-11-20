# frozen_string_literal: true

class AssessmentBlueprintsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_assessment_blueprint, only: %i[show edit update destroy]

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
      redirect_to assessment_blueprints_path, notice: "Blueprint asesmen ditambahkan."
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
    @assessment_blueprint.destroy
    redirect_to assessment_blueprints_path, notice: "Blueprint asesmen dihapus.", status: :see_other
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
