# frozen_string_literal: true

class WpbaObservationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_observation, only: %i[show edit update destroy submit correction create_correction]
  before_action :require_wpba_enabled, only: %i[new create edit update destroy submit correction create_correction]

  def show
    authorize @observation
    if @observation.multisource_feedback? && @observation.student_id == current_user.id
      @multisource_group = @observation.multisource_group
      @multisource_ready = @observation.multisource_ready?
    end
  end

  def new
    authorize WpbaObservation
    @observation = WpbaObservation.new(observed_at: Time.current, observer: current_user)
    load_form_collections
  end

  def create
    authorize WpbaObservation
    @observation = WpbaObservation.new(observation_params)
    @observation.observer = current_user
    @observation.status = "draft"
    authorize @observation, :create_for_assigned_student?
    if @observation.save
      redirect_to @observation, notice: "Draf observasi WPBA disimpan."
    else
      load_form_collections
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @observation
    load_form_collections
  end

  def update
    authorize @observation
    if @observation.update(observation_params)
      redirect_to @observation, notice: "Draf observasi WPBA diperbarui."
    else
      load_form_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @observation
    @observation.destroy
    redirect_to assessments_path, notice: "Draf observasi WPBA dihapus.", status: :see_other
  end

  def submit
    authorize @observation
    @observation.submit!
    redirect_to @observation, notice: "Observasi WPBA dikirim sebagai bukti formatif."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to @observation, alert: error.record.errors.full_messages.to_sentence
  end

  def correction
    authorize @observation, :correct?
  end

  def create_correction
    authorize @observation, :correct?
    reason = params.require(:correction_reason).to_s.strip
    raise ArgumentError, "Alasan koreksi minimal 10 karakter." if reason.length < 10

    correction = @observation.dup
    correction.assign_attributes(status: "draft", submitted_at: nil, observer: current_user,
      corrects: @observation, correction_reason: reason)
    correction.save!
    redirect_to edit_wpba_observation_path(correction), notice: "Draf koreksi dibuat; observasi awal tetap tersimpan."
  rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ActionController::ParameterMissing => error
    redirect_to @observation, alert: error.message
  end

  private

  def set_observation
    @observation = policy_scope(WpbaObservation).find(params[:id])
  end

  def load_form_collections
    @rotations = AssessmentAssignment.wpba_enabled_rotations_for(current_user).includes(:user).order(start_date: :desc)
    assigned_rotation_ids = @rotations.unscope(:order).pluck(:id)
    student_ids = ClinicalRotation.where(id: assigned_rotation_ids).distinct.pluck(:user_id)
    @students = User.active_accounts.where(id: student_ids).order(:full_name)
    @instrument_versions = WpbaInstrumentVersion.includes(:wpba_instrument)
      .joins(:wpba_instrument).where(wpba_instruments: { active: true, instrument_type: WpbaInstrument::WPBA_TYPES + ["other"] })
      .where.not(published_at: nil).order("wpba_instruments.name", published_at: :desc)
    @cases = ClinicalCase.where(user_id: student_ids).order(created_at: :desc).limit(100)
    selected_version_id = params.dig(:wpba_observation, :wpba_instrument_version_id) || params[:wpba_instrument_version_id]
    @selected_version = @instrument_versions.find_by(id: selected_version_id) ||
      @observation.wpba_instrument_version
    @observation.wpba_instrument_version ||= @selected_version
  end

  def observation_params
    params.require(:wpba_observation).permit(:student_id, :clinical_rotation_id, :clinical_case_id,
      :wpba_instrument_version_id, :observed_at, :activity_summary, :overall_feedback, :action_plan,
      clinical_context: %i[complexity setting patient_age_group], responses: {})
  end

  def require_wpba_enabled
    if action_name == "new"
      allowed = AssessmentAssignment.wpba_enabled_rotations_for(current_user).exists?
    else
      student = @observation&.student || student_for_submitted_rotation
      allowed = student.present? && ModuleConfiguration.for(student.study_program).enabled?("wpba")
    end
    return if allowed

    redirect_to assessments_path, alert: "Input WPBA sedang dinonaktifkan; riwayat observasi tetap dapat dibaca."
  end

  def student_for_submitted_rotation
    rotation = ClinicalRotation.find_by(id: params.dig(:wpba_observation, :clinical_rotation_id))
    student_id = params.dig(:wpba_observation, :student_id)
    rotation.user if rotation && rotation.user_id.to_s == student_id.to_s
  end
end
