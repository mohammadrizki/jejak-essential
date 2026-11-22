# frozen_string_literal: true

class ModuleConfigurationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_study_program

  def edit
    @configuration = ModuleConfiguration.for(@study_program)
    @study_programs = manageable_programs
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
    if params[:study_program_id].present?
      @study_program = StudyProgram.find(params[:study_program_id])
    else
      @study_program = manageable_programs.first
    end
    return if @study_program && (current_user.has_role?("superadmin") ||
      current_user.has_permission?("modules.manage", study_program: @study_program))

    redirect_to dashboard_path, alert: "Permission aktivasi modul pada program studi ini diperlukan."
  end

  def manageable_programs
    return StudyProgram.ordered if current_user.has_role?("superadmin")

    StudyProgram.ordered.select { |program| current_user.has_permission?("modules.manage", study_program: program) }
  end

  def configuration_params
    params.require(:modules).permit(:clinical_logbook, :wpba, :epa,
      :integration_sia, :integration_moodle, :integration_examtool, :integration_osce,
      :integration_clinical_wpba)
  end
end
