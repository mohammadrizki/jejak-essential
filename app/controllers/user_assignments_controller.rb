# frozen_string_literal: true

class UserAssignmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_assignment, only: :destroy

  def index
    authorize UserAssignment
    @assignments = policy_scope(UserAssignment).includes(:user, :assigned_by, :study_program)
      .order(revoked_at: :asc, created_at: :desc)
    @study_programs = current_user.has_role?("admin") ? StudyProgram.ordered : StudyProgram.where(id: current_user.study_program_id)
    @assignees = User.active_accounts.joins(:roles)
      .where(roles: { code: %w[dosen kaprodi preseptor tenaga_kependidikan] })
      .where(current_user.has_role?("admin") ? {} : { study_program_id: current_user.study_program_id })
      .distinct.order(:full_name)
    @students = User.active_accounts.joins(:roles).where(roles: { code: "mahasiswa" })
      .where(study_program_id: @study_programs.select(:id)).distinct.order(:full_name)
  end

  def create
    authorize UserAssignment
    program = permitted_program
    assignee = User.active_accounts.find(params.require(:user_assignment).require(:user_id))
    role = params.dig(:user_assignment, :assignment_role).to_s
    scope_type, scope_id = if role == "external_data_manager"
      ["StudyProgram", program.id]
    else
      assignment_scope(program)
    end
    @assignment = UserAssignment.new(user: assignee, assigned_by: current_user, study_program: program,
      assignment_role: role, scope_type: scope_type, scope_id: scope_id,
      starts_on: params.dig(:user_assignment, :starts_on), ends_on: params.dig(:user_assignment, :ends_on),
      reason: params.dig(:user_assignment, :reason))
    raise Pundit::NotAuthorizedError unless assignment_target_allowed?(program, assignee)

    if @assignment.save
      redirect_to user_assignments_path, notice: "Penugasan dicatat."
    else
      redirect_to user_assignments_path, alert: @assignment.errors.full_messages.to_sentence
    end
  rescue ActiveRecord::RecordNotFound, ActionController::ParameterMissing, Pundit::NotAuthorizedError
    redirect_to dashboard_path, alert: "Lingkup penugasan tidak diizinkan."
  end

  def destroy
    authorize @assignment
    @assignment.revoke!(by: current_user, reason: params[:reason])
    redirect_to user_assignments_path, notice: "Penugasan dicabut; riwayatnya tetap tersimpan."
  rescue ArgumentError, ActiveRecord::RecordInvalid => error
    redirect_to user_assignments_path, alert: error.message
  end

  private

  def permitted_program
    return current_user.study_program if current_user.has_role?("kaprodi") && !current_user.has_role?("admin")

    StudyProgram.find(params.dig(:user_assignment, :study_program_id))
  end

  def assignment_scope(program)
    params.dig(:user_assignment, :scope_type).to_s.then do |type|
      case type
      when "student"
        ["User", User.active_accounts.joins(:roles).where(roles: { code: "mahasiswa" },
          study_program_id: program.id).find(params.dig(:user_assignment, :student_id)).id]
      when "program" then ["StudyProgram", program.id]
      when "rotation"
        rotation = ClinicalRotation.joins(:user).where(users: { study_program_id: program.id })
          .find(params.dig(:user_assignment, :clinical_rotation_id))
        ["ClinicalRotation", rotation.id]
      else
        [nil, nil]
      end
    end
  end

  def assignment_target_allowed?(program, assignee)
    return false unless current_user.has_role?("admin") ||
      (current_user.has_role?("kaprodi") && current_user.study_program_id == program.id)
    return true if current_user.has_role?("admin")

    assignee.study_program_id == program.id
  end

  def set_assignment
    @assignment = UserAssignment.find(params[:id])
  end
end
