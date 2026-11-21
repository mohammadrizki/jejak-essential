# frozen_string_literal: true

class EpaObservationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @student = params[:student_id].present? ? User.find(params[:student_id]) : current_user
    unless can_view_dossier?(@student)
      redirect_to dashboard_path, alert: "Anda tidak memiliki akses ke portofolio EPA mahasiswa ini." and return
    end
    @observations = @student.epa_observations.includes(:epa, :observer, :supervision_level, :clinical_case).chronological
    @promotions = @student.epa_promotions.includes(:epa).order(eligible_at: :desc)
  end

  def new
    @student = User.find(params[:student_id])
    @epa = Epa.find(params[:epa_id])
    return deny_access unless assigned_observer?(@student, @epa)

    @observation = EpaObservation.new(student: @student, epa: @epa, observed_at: Time.current)
    @scales = SupervisionScaleVersion.where(active: true, use_case: "retrospective_observation").includes(:supervision_levels)
  end

  def create
    @student = User.find(params.require(:epa_observation).fetch(:student_id))
    @epa = Epa.find(params.require(:epa_observation).fetch(:epa_id))
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
    return deny_access unless current_user.has_role?("admin") ||
      (current_user.has_role?("kaprodi") && current_user.study_program_id == observation.student.study_program_id)

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
    return false if student == current_user || !student.has_role?("mahasiswa") || !current_user.instructor?
    return false unless epa.competency_framework.study_program_id == student.study_program_id
    return false unless epa.competency_framework.status == "published" && epa.status == "published"

    observation_time = Time.zone.parse(params.dig(:epa_observation, :observed_at).to_s) rescue nil
    observation_date = observation_time&.to_date || Date.current
    current_user.precepted_rotations.where(user: student).covering(observation_date).exists? ||
      student.clinical_cases.where(supervisor: current_user).where(case_date: observation_date).exists? ||
      student.verified_clinical_cases.where(verified_by: current_user, case_date: observation_date).exists?
  end

  def can_view_dossier?(student)
    return true if student == current_user
    return true if current_user.has_role?("admin")
    return true if current_user.has_role?("kaprodi") && current_user.study_program_id == student.study_program_id

    student.clinical_rotations.exists?(preceptor: current_user) ||
      student.clinical_cases.exists?(supervisor: current_user) ||
      student.verified_clinical_cases.exists?(verified_by: current_user)
  end

  def deny_access
    redirect_to dashboard_path, alert: "Observasi EPA hanya dapat diisi oleh pengamat yang ditugaskan." 
  end
end
