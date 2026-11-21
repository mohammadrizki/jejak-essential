# frozen_string_literal: true

class CompetencyFrameworkTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_template, only: %i[show duplicate]

  def index
    authorize CompetencyFramework
    @templates = CompetencyFrameworkTemplate.all
  end

  def show
    authorize CompetencyFramework
    @study_programs = StudyProgram.ordered if current_user.has_role?("admin")
  end

  def duplicate
    authorize CompetencyFramework, :create?
    target_program = StudyProgram.find(params.require(:study_program_id))
    framework = CompetencyFrameworkDuplicator.new(
      template: @template,
      study_program: target_program,
      name: params[:name].presence || @template.name
    ).call
    redirect_to framework, notice: "Template disalin ke Peta Kompetensi sebagai draf independen versi #{framework.version}."
  rescue ActiveRecord::RecordInvalid => e
    @study_programs = StudyProgram.ordered
    @duplicate_errors = e.record.errors.full_messages
    render :show, status: :unprocessable_entity
  end

  private

  def set_template
    @template = CompetencyFrameworkTemplate.find_by_key(params[:id])
    raise ActiveRecord::RecordNotFound if @template.blank?
  end
end
