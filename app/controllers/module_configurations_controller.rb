# frozen_string_literal: true

class ModuleConfigurationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_study_program

  def edit
    @configuration = ModuleConfiguration.for(@study_program)
    @study_programs = StudyProgram.ordered if current_user.has_role?("admin")
    @history = ModuleConfigurationChange.where(study_program: @study_program)
      .includes(:actor).order(created_at: :desc).limit(20)
  end

  def update
    @configuration = ModuleConfiguration.for(@study_program)
    @configuration.update!(configuration_params, actor: current_user)
    redirect_to edit_module_configuration_path(study_program_id: @study_program.id),
      notice: "Aktivasi modul program studi diperbarui."
  rescue ArgumentError, Pundit::NotAuthorizedError => error
    redirect_to edit_module_configuration_path(study_program_id: @study_program.id), alert: error.message
  end

  private

  def set_study_program
    if current_user.has_role?("admin")
      @study_program = StudyProgram.find(params.require(:study_program_id))
    elsif current_user.has_role?("kaprodi") && current_user.study_program_id.present?
      @study_program = current_user.study_program
      if params[:study_program_id].present? && params[:study_program_id].to_i != @study_program.id
        return redirect_to dashboard_path, alert: "Kaprodi hanya dapat mengatur modul program studinya."
      end
    else
      redirect_to dashboard_path, alert: "Anda tidak berwenang mengatur modul program studi."
    end
  end

  def configuration_params
    params.require(:modules).permit(:clinical_logbook, :wpba, :epa)
  end
end
