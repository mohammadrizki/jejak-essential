# frozen_string_literal: true

class ExternalIdentityMappingsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_manager!
  before_action :set_mapping, only: :update

  def index
    @programs = managed_programs
    students = User.active_accounts.joins(:roles).where(roles: { code: "mahasiswa" })
      .where(study_program_id: @programs.select(:id)).distinct
    @students = students.order(:full_name)
    @mappings = ExternalIdentityMapping.where(internal_record_type: "User",
      internal_record_id: @students.reorder(nil).select(:id)).includes(:created_by, events: :changed_by).order(updated_at: :desc)
  end

  def create
    student = scoped_students.find(params.dig(:external_identity_mapping, :student_id))
    source_system = params.dig(:external_identity_mapping, :source_system).to_s
    raise ArgumentError, "Sistem sumber tidak dikenal." unless source_system.in?(%w[sia moodle examtool osce])

    ExternalIdentityResolver.map_student!(source_system: source_system,
      external_id: params.dig(:external_identity_mapping, :external_id), student: student,
      by: current_user, authority: "manual", revision: params.dig(:external_identity_mapping, :source_revision))
    redirect_to external_identity_mappings_path, notice: "Identifier eksternal dipetakan ke ID internal JEJAK."
  rescue ActiveRecord::RecordNotFound, ArgumentError, ActiveRecord::RecordInvalid => error
    redirect_to external_identity_mappings_path, alert: error.message
  end

  def update
    student = scoped_students.find(params.dig(:external_identity_mapping, :student_id))
    @mapping.reconcile!(student: student, by: current_user, reason: params.dig(:external_identity_mapping, :reason))
    redirect_to external_identity_mappings_path, notice: "Pemetaan direkonsiliasi dan riwayat perubahan tersimpan."
  rescue ActiveRecord::RecordNotFound, ArgumentError, ActiveRecord::RecordInvalid, Pundit::NotAuthorizedError => error
    redirect_to external_identity_mappings_path, alert: error.message
  end

  private

  def authorize_manager!
    return if managed_programs.exists?

    redirect_to dashboard_path, alert: "Pengelolaan pemetaan identitas eksternal memerlukan penugasan program studi."
  end

  def scoped_students
    scope = User.active_accounts.joins(:roles).where(roles: { code: "mahasiswa" })
    scope.where(study_program_id: managed_programs.select(:id)).distinct
  end

  def managed_programs
    return StudyProgram.ordered if current_user.has_role?("superadmin")

    permitted_ids = current_user.programs_with_permission("integration.manage").map(&:id)

    assignments = UserAssignment.active.where(user: current_user, assignment_role: "external_data_manager",
      scope_type: "StudyProgram").where("user_assignments.scope_id = user_assignments.study_program_id")
    StudyProgram.where(id: permitted_ids).or(StudyProgram.where(id: assignments.select(:study_program_id))).distinct
  end

  def set_mapping
    ids = ExternalIdentityMapping.where(internal_record_type: "User", internal_record_id: scoped_students.select(:id)).select(:id)
    @mapping = ExternalIdentityMapping.find(params[:id])
    raise ActiveRecord::RecordNotFound unless ids.exists?(@mapping.id)
  end
end
