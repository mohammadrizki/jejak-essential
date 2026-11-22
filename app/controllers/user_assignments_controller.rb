# frozen_string_literal: true

class UserAssignmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_assignment, only: :destroy

  def index
    authorize UserAssignment
    @assignments = policy_scope(UserAssignment).includes(:user, :assigned_by, :study_program)
      .order(revoked_at: :asc, created_at: :desc)
    @study_program_ids = if current_user.has_role?("superadmin")
      StudyProgram.pluck(:id)
    else
      StudyProgram.ordered.select { |program| current_user.has_permission?("assignments.manage", study_program: program) }.map(&:id)
    end
    @study_programs = StudyProgram.where(id: @study_program_ids).order(:name)
    @study_programs = if current_user.has_role?("superadmin")
      StudyProgram.ordered
    else
      @study_programs
    end
    @assignees = User.active_accounts.joins(:roles)
      .where(roles: { code: %w[dosen kaprodi preseptor tenaga_kependidikan] })
      .where(study_program_id: @study_program_ids)
      .distinct.order(:full_name)
    @students = User.active_accounts.joins(:roles).where(roles: { code: "mahasiswa" })
      .where(study_program_id: @study_program_ids).distinct.order(:full_name)
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
    program = StudyProgram.find(params.dig(:user_assignment, :study_program_id))
    raise Pundit::NotAuthorizedError unless current_user.has_role?("superadmin") ||
      current_user.has_permission?("assignments.manage", study_program: program)

    program
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
    current_user.has_role?("superadmin") || current_user.has_permission?("assignments.manage", study_program: program)
  end

  def set_assignment
    @assignment = UserAssignment.find(params[:id])
  end
end
