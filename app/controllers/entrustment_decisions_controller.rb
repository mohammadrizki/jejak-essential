# frozen_string_literal: true

# Peta EPA & Tingkat Entrustment (/dashboard/entrustment):
# mahasiswa melihat levelnya per ranah; pembimbing (tutor/preseptor/dosen/
# admin yang punya relasi) mengisi/memperbarui dengan justifikasi naratif.
class EntrustmentDecisionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_student
  before_action :authorize_ad_hoc_decision!, only: %i[new create]

  def index
    @epa_module_enabled = @student.study_program.present? && ModuleConfiguration.for(@student.study_program).enabled?("epa")

    @framework = CompetencyFramework.for_student(@student)
    @map = @framework ? EntrustmentDecision.map_for(@student, @framework) : []
    @ad_hoc_by_epa = EntrustmentDecision.current.where(student: @student, decision_kind: "ad_hoc")
      .where.not(epa_id: nil).includes(:supervision_level).index_by(&:epa_id)
    @promotion_status_by_epa = EpaPromotion.where(student: @student, epa_id: @map.map(&:first).map(&:id)).index_by(&:epa_id)
    @history = EntrustmentDecision.where(student: @student).includes(:competency_item, :decided_by, :clinical_case).history.limit(30)
    @appealable_promotions = @student == current_user ? EpaPromotion.where(student: @student,
      status: %w[approved restricted not_entrusted deferred]).where.not(finalized_at: nil) : EpaPromotion.none
    @can_decide = can_decide?
    @ad_hoc_decisions = @history.where(decision_kind: "ad_hoc")
  end

  def new
    @framework = CompetencyFramework.for_student(@student)
    @epas = @framework ? @framework.epas.order(:code) : Epa.none
    @scale_versions = SupervisionScaleVersion.where(use_case: "prospective_entrustment").includes(:supervision_levels).order(:name, :version_label)
    @rotations = @student.clinical_rotations.ongoing
  end

  def create
    attributes = decision_params
    epa = @student.study_program&.peta_kompetensi&.epas&.find_by(id: attributes[:epa_id]) if attributes[:epa_id].present?
    scale_version = SupervisionScaleVersion.find_by(id: attributes[:supervision_scale_version_id], use_case: "prospective_entrustment")
    level = scale_version&.supervision_levels&.find_by(id: attributes[:supervision_level_id])
    rotation = @student.clinical_rotations.ongoing.find_by(id: attributes[:clinical_rotation_id]) if attributes[:clinical_rotation_id].present?
    context = { "rotation_id" => rotation&.id, "setting" => attributes[:setting],
      "case_complexity" => attributes[:case_complexity] }.compact

    decision = EntrustmentDecision.decide!(student: @student, epa: epa, level: level&.ordinal,
      supervision_level: level, justification: attributes[:justification], decided_by: current_user,
      decision_kind: "ad_hoc", activity_description: attributes[:activity_description],
      scope_limitations: attributes[:scope_limitations], context: context,
      valid_from: attributes[:valid_from].presence || Time.current,
      valid_until: attributes[:valid_until].presence)
    redirect_to entrustment_decisions_path(student_id: @student.id),
      notice: "Keputusan entrustment ad hoc ##{decision.id} berhasil dicatat."
  rescue ActiveRecord::RecordInvalid, ArgumentError => error
    @framework ||= CompetencyFramework.for_student(@student)
    @epas ||= @framework ? @framework.epas.order(:code) : Epa.none
    @scale_versions ||= SupervisionScaleVersion.where(use_case: "prospective_entrustment").includes(:supervision_levels)
    @rotations ||= @student.clinical_rotations.ongoing
    @decision_error = error.message
    render :new, status: :unprocessable_entity
  end

  private

  # Mahasiswa hanya peta miliknya; pengajar & kaprodi (prodi binaannya saja)
  # boleh membuka mahasiswa lain — kaprodi hanya melihat, lihat can_decide?.
  def set_student
    @student = params[:student_id].present? ? User.find(params[:student_id]) : current_user
    raise Pundit::NotAuthorizedError unless @student.has_role?("mahasiswa") && (@student == current_user || assigned_to_epa?(@student))
  end

  def can_decide?
    ad_hoc_authorized?
  end

  def authorize_ad_hoc_decision!
    raise Pundit::NotAuthorizedError unless ad_hoc_authorized?
  end

  def ad_hoc_authorized?
    return false unless @student && @student.study_program && ModuleConfiguration.for(@student.study_program).enabled?("epa")
    return false unless current_user.has_role?("preseptor") || current_user.has_role?("dosen") || current_user.has_role?("kaprodi")

    rotation = @student.clinical_rotations.ongoing.find_by(preceptor: current_user)
    return true if rotation

    UserAssignment.active.where(user: current_user, assignment_role: "epa_ad_hoc_decider")
      .where("study_program_id IS NULL OR study_program_id = ?", @student.study_program_id)
      .where("(scope_type = 'User' AND scope_id = ?) OR (scope_type = 'StudyProgram' AND scope_id = ?) OR (scope_type = 'ClinicalRotation' AND scope_id IN (?))",
        @student.id, @student.study_program_id, @student.clinical_rotations.select(:id)).exists?
  end

  def decision_params
    params.require(:entrustment_decision).permit(:epa_id, :activity_description, :scope_limitations,
      :justification, :supervision_scale_version_id, :supervision_level_id, :clinical_rotation_id,
      :setting, :case_complexity, :valid_from, :valid_until)
  end

  def assigned_to_epa?(student)
    return true if student.clinical_rotations.ongoing.exists?(preceptor: current_user)

    promotion_ids = EpaPromotion.where(student: student).select(:id)
    UserAssignment.active.where(user: current_user, assignment_role: %w[epa_panel_member epa_panel_chair],
      scope_type: "EpaPromotion", scope_id: promotion_ids).exists? ||
      UserAssignment.active.where(user: current_user, assignment_role: %w[epa_panel_member epa_panel_chair],
        scope_type: "User", scope_id: student.id).exists? ||
      UserAssignment.active.where(user: current_user, assignment_role: %w[epa_panel_member epa_panel_chair],
        scope_type: "StudyProgram", scope_id: student.study_program_id).exists? ||
      UserAssignment.active.where(user: current_user, assignment_role: "epa_ad_hoc_decider",
        scope_type: "User", scope_id: student.id).exists? ||
      UserAssignment.active.where(user: current_user, assignment_role: "epa_ad_hoc_decider",
        scope_type: "StudyProgram", scope_id: student.study_program_id).exists? ||
      UserAssignment.active.where(user: current_user, assignment_role: "epa_ad_hoc_decider",
        scope_type: "ClinicalRotation", scope_id: student.clinical_rotations.select(:id)).exists?
  end
end
