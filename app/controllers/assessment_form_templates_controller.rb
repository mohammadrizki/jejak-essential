# frozen_string_literal: true

class AssessmentFormTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_template, only: %i[show edit update destroy]

  def index
    authorize AssessmentFormTemplate
    @templates = policy_scope(AssessmentFormTemplate).includes(:study_program).order(:name)
  end

  def show
    authorize @template
  end

  def new
    authorize AssessmentFormTemplate, :create?
    @template = AssessmentFormTemplate.new
    load_study_programs
    @template.study_program = @study_programs.first unless current_user.has_role?("superadmin")
  end

  def create
    authorize AssessmentFormTemplate, :create?
    @template = AssessmentFormTemplate.new(template_params)
    @template.created_by = current_user
    load_study_programs
    if current_user.has_role?("superadmin")
      @template.study_program = StudyProgram.find_by(id: params.dig(:assessment_form_template, :study_program_id)) if params.dig(:assessment_form_template, :study_program_id).present?
    else
      @template.study_program = @study_programs.find_by(id: params.dig(:assessment_form_template, :study_program_id)) || @study_programs.first
    end
    unless @template.study_program || current_user.has_role?("superadmin")
      return redirect_to assessment_form_templates_path, alert: "Pilih program studi dalam cakupan kelola kurikulum Anda."
    end

    if @template.save
      redirect_to @template, notice: "Formulir berhasil dibuat. Sekarang tambahkan pertanyaan."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @template
    load_study_programs
  end

  def update
    authorize @template
    if @template.update(template_params)
      redirect_to @template, notice: "Formulir diperbarui."
    else
      load_study_programs
      render :edit, status: :unprocessable_entity
    end
  end

  # Menghapus template ikut menghapus seluruh jawaban & memutus nilai asesmen
  # yang berangkat darinya. Bila sudah dipakai, arahkan ke nonaktifkan.
  def destroy
    authorize @template
    if @template.assessment_form_submissions.exists?
      redirect_to @template, alert: "Formulir ini sudah punya jawaban, jadi tidak dapat dihapus. Nonaktifkan saja lewat Sunting agar tidak dipakai lagi."
      return
    end
    if AssessmentEvent.exists?(assessment_form_template: @template)
      redirect_to @template, alert: "Formulir ini dipakai sebagai rubrik pada Assessment Event. Lepaskan dulu dari event tersebut."
      return
    end

    @template.destroy
    redirect_to assessment_form_templates_path, notice: "Formulir dihapus.", status: :see_other
  end

  private

  def set_template
    @template = policy_scope(AssessmentFormTemplate).find(params[:id])
  end

  def template_params
    permitted = %i[name description is_active anonymous requires_subject_user]
    permitted << :study_program_id
    params.require(:assessment_form_template).permit(*permitted)
  end

  def load_study_programs
    @study_programs = current_user.has_role?("superadmin") ? StudyProgram.ordered :
      StudyProgram.where(id: current_user.programs_with_permission("curriculum.manage").map(&:id)).ordered
  end
end
