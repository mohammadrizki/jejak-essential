# frozen_string_literal: true

class Admin::LogbookCaseTargetsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_target, only: %i[edit update destroy]

  def index
    @targets = target_scope.includes(:study_program, :academic_period).ordered
  end

  def new
    @target = LogbookCaseTarget.new(facility_type: "fktp")
    load_collections
  end

  def create
    @target = LogbookCaseTarget.new(target_params)
    if permitted_program?(@target.study_program)
      if @target.save
        redirect_to admin_logbook_case_targets_path, notice: "Target kasus disimpan."
      else
        load_collections
        render :new, status: :unprocessable_entity
      end
    else
      @target.errors.add(:study_program, "berada di luar cakupan program studi Anda")
      load_collections
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_collections
  end

  def update
    attributes = target_params
    if permitted_program?(StudyProgram.find_by(id: attributes[:study_program_id])) && @target.update(attributes)
      redirect_to admin_logbook_case_targets_path, notice: "Target kasus diperbarui."
    else
      @target.errors.add(:study_program, "berada di luar cakupan program studi Anda") if @target.errors.empty?
      load_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @target.destroy
    redirect_to admin_logbook_case_targets_path, notice: "Target kasus dihapus.", status: :see_other
  end

  private

  def require_admin!
    return if current_user.has_role?("superadmin") || current_user.programs_with_permission("curriculum.manage").any?

    redirect_to dashboard_path, alert: "Halaman ini khusus admin."
  end

  def set_target
    @target = target_scope.find(params[:id])
  end

  def load_collections
    @study_programs = manageable_programs
    @academic_periods = AcademicPeriod.ordered
  end

  def target_params
    permitted = params.require(:logbook_case_target).permit(:study_program_id, :academic_period_id, :facility_type, :target_count, :notes)
    unless current_user.has_role?("superadmin")
      requested_id = permitted[:study_program_id]
      permitted[:study_program_id] = requested_id if manageable_programs.exists?(id: requested_id)
    end
    permitted
  end

  def manageable_programs
    current_user.has_role?("superadmin") ? StudyProgram.ordered :
      StudyProgram.where(id: current_user.programs_with_permission("curriculum.manage").map(&:id)).ordered
  end

  def target_scope
    return LogbookCaseTarget.all if current_user.has_role?("superadmin")

    LogbookCaseTarget.where(study_program_id: manageable_programs.select(:id))
  end

  def permitted_program?(program)
    current_user.has_role?("superadmin") || current_user.permitted_for_program?(program, "curriculum.manage")
  end
end
