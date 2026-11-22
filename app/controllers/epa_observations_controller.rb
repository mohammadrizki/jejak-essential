# frozen_string_literal: true

class EpaObservationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @student = params[:student_id].present? ? User.find(params[:student_id]) : current_user
    unless can_view_dossier?(@student)
      redirect_to dashboard_path, alert: "Anda tidak memiliki akses ke portofolio EPA mahasiswa ini." and return
    end
    @observations = @student.epa_observations.includes(:epa, :observer, :clinical_case,
      supervision_level: :supervision_scale_version).chronological
    framework = @student.study_program&.peta_kompetensi
    @epas = if framework&.status == "published" && framework.education_stage.in?(%w[undergraduate professional specialist subspecialist]) &&
        ModuleConfiguration.for(@student.study_program).enabled?("epa")
      framework.epas.where(status: "published").includes(:evidence_requirements).order(:code)
    else
      Epa.none
    end
    @observable_epa_ids = @epas.select { |epa| assigned_observer?(@student, epa) }.map(&:id).to_set
    @promotions_by_epa = @student.epa_promotions.includes(:epa).order(eligible_at: :desc).group_by(&:epa_id)
    @readiness = @epas.index_with do |epa|
      EpaPromotionReadiness.new(student: @student, epa: epa).call
    end
    @requirement_progress = @epas.index_with do |epa|
      epa.evidence_requirements.where(status: "active").includes(:evidence_records).to_h do |requirement|
        [requirement, EvidenceRequirementProgress.new(requirement, student: @student).call]
      end
    end
    @gating_requirement_progress = @epas.index_with do |epa|
      @requirement_progress.fetch(epa).select do |requirement, progress|
        configuration = progress.requirement_version&.configuration || requirement.configuration_snapshot
        configuration.fetch("is_mandatory", requirement.is_mandatory?) ||
          configuration.dig("fulfillment_rule", "critical")
      end
    end
    all_cycle_observations = EpaObservation.where(student: @student, epa_id: @epas.select(:id))
      .includes(:clinical_rotation, :clinical_case, :observer,
        supervision_level: :supervision_scale_version).chronological.to_a
    @usable_observations_by_epa = all_cycle_observations.select do |observation|
      observation.status == "recorded" && (!observation.safety_flag? || observation.safety_resolved_at.present?)
    end.group_by(&:epa_id)
    student_rotations = @student.clinical_rotations.includes(:academic_period).to_a
    @cycle_evidence_summaries = @epas.index_with do |epa|
      EpaCycleEvidenceSummary.new(student: @student, epa: epa,
        observations: all_cycle_observations, rotations: student_rotations).call
    end
    @current_decisions = EntrustmentDecision.current.where(student: @student, epa: @epas).includes(:supervision_level).index_by(&:epa_id)
  end

  def new
    @student = User.find(params[:student_id])
    @epa = Epa.find(params[:epa_id])
    return module_disabled unless ModuleConfiguration.for(@student.study_program).enabled?("epa")
    return deny_access unless assigned_observer?(@student, @epa)

    @observation = EpaObservation.new(student: @student, epa: @epa, observed_at: Time.current)
    @scales = SupervisionScaleVersion.where(active: true, use_case: "retrospective_observation").includes(:supervision_levels)
  end

  def create
    @student = User.find(params.require(:epa_observation).fetch(:student_id))
    @epa = Epa.find(params.require(:epa_observation).fetch(:epa_id))
    return module_disabled unless ModuleConfiguration.for(@student.study_program).enabled?("epa")
    return deny_access unless assigned_observer?(@student, @epa)

    @observation = EpaObservation.new(observation_params.merge(student: @student, epa: @epa, observer: current_user,
      status: "recorded", submitted_at: Time.current))
    if @observation.save
      redirect_to epa_observations_path(student_id: @student.id), notice: "Observasi formatif EPA tersimpan. Observasi ini bukan keputusan entrustment."
    else
      @scales = SupervisionScaleVersion.where(active: true, use_case: "retrospective_observation").includes(:supervision_levels)
      render :new, status: :unprocessable_entity
    end
  end

  def resolve_safety
    observation = EpaObservation.find(params[:id])
    return deny_access unless AssignmentAuthorization.assigned?(user: current_user, role: "epa_panel_member",
      student: observation.student)

    observation.resolve_safety!(by: current_user, resolution: params.require(:safety_resolution))
    redirect_to epa_observations_path(student_id: observation.student_id), notice: "Tindak lanjut keselamatan EPA dicatat."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to epa_observations_path(student_id: observation.student_id), alert: error.record.errors.full_messages.to_sentence
  end

  private

  def observation_params
    params.require(:epa_observation).permit(:clinical_case_id, :clinical_rotation_id, :supervision_level_id,
      :observed_at, :complexity, :activity_scope, :narrative, :strengths, :areas_to_improve, :safety_flag)
  end

  def assigned_observer?(student, epa)
    return false if student == current_user || !student.has_role?("mahasiswa")
    return false unless epa.competency_framework.study_program_id == student.study_program_id
    return false unless epa.competency_framework.status == "published" && epa.status == "published"

    observation_time = Time.zone.parse(params.dig(:epa_observation, :observed_at).to_s) rescue nil
    observation_date = observation_time&.to_date || Date.current
    explicitly_assigned_epa_observer?(student, observation_date) ||
      (clinical_observer? && current_user.precepted_rotations.where(user: student).covering(observation_date).exists?) ||
      (clinical_observer? && student.clinical_cases.where(supervisor: current_user).where(case_date: observation_date).exists?) ||
      (clinical_observer? && student.verified_clinical_cases.where(verified_by: current_user, case_date: observation_date).exists?)
  end

  def explicitly_assigned_epa_observer?(student, observation_date)
    assignments = UserAssignment.active.where(user: current_user, assignment_role: "epa_observer")
    assignments.any? do |assignment|
      next false if assignment.study_program_id.present? && assignment.study_program_id != student.study_program_id

      case assignment.scope_type
      when "ClinicalRotation"
        rotation_id = params.dig(:epa_observation, :clinical_rotation_id)
        next false if params[:epa_observation].present? && rotation_id.blank?

        rotations = student.clinical_rotations.where(id: rotation_id || assignment.scope_id)
          .where("start_date <= ? AND end_date >= ?", observation_date, observation_date)
        rotations.any? { |rotation| assignment.matches?(role: "epa_observer", student: student, object: rotation) }
      else
        assignment.matches?(role: "epa_observer", student: student)
      end
    end
  end

  def can_view_dossier?(student)
    return true if student == current_user
    return true if student.epa_promotions.any? do |promotion|
      AssignmentAuthorization.assigned?(user: current_user, role: "epa_panel_member", student: student, object: promotion)
    end
    return true if explicitly_assigned_epa_observer_for_student?(student)
    return true if clinical_observer? && student.clinical_rotations.ongoing.exists?(preceptor: current_user)
    return false unless clinical_observer?

    student.clinical_cases.exists?(supervisor: current_user, case_date: Date.current) ||
      student.verified_clinical_cases.exists?(verified_by: current_user, case_date: Date.current)
  end

  def clinical_observer?
    current_user.has_role?("dosen") || current_user.has_role?("preseptor")
  end

  def explicitly_assigned_epa_observer_for_student?(student)
    UserAssignment.active.where(user: current_user, assignment_role: "epa_observer").any? do |assignment|
      if assignment.scope_type == "ClinicalRotation"
        student.clinical_rotations.where(id: assignment.scope_id).any? do |rotation|
          assignment.matches?(role: "epa_observer", student: student, object: rotation)
        end
      else
        assignment.matches?(role: "epa_observer", student: student)
      end
    end
  end

  def deny_access
    redirect_to dashboard_path, alert: "Observasi EPA hanya dapat diisi oleh pengamat yang ditugaskan." 
  end

  def module_disabled
    redirect_to epa_observations_path(student_id: @student.id),
      alert: "Input EPA untuk program studi ini sedang dinonaktifkan; riwayat tetap dapat dibaca."
  end
end
