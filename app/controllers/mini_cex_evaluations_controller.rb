# frozen_string_literal: true

class MiniCexEvaluationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_mini_cex_evaluation, only: %i[show edit update destroy submit correction create_correction]
  before_action :require_wpba_enabled, only: %i[new create edit update destroy submit correction create_correction]

  def show
    authorize @mini_cex_evaluation
  end

  def new
    authorize MiniCexEvaluation
    @mini_cex_evaluation = MiniCexEvaluation.new(evaluated_at: Date.current, evaluator: current_user,
      wpba_instrument_version: WpbaInstrumentCatalog.version_for("mini_cex"))
    load_form_collections
  end

  def create
    authorize MiniCexEvaluation
    @mini_cex_evaluation = MiniCexEvaluation.new(mini_cex_evaluation_params)
    @mini_cex_evaluation.evaluator = current_user
    @mini_cex_evaluation.wpba_instrument_version ||= WpbaInstrumentCatalog.version_for("mini_cex")
    authorize @mini_cex_evaluation, :create_for_assigned_student?

    if @mini_cex_evaluation.save
      redirect_to @mini_cex_evaluation, notice: "Evaluasi Mini-CEX berhasil disimpan."
    else
      load_form_collections
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @mini_cex_evaluation
    load_form_collections
  end

  def update
    authorize @mini_cex_evaluation
    if @mini_cex_evaluation.update(mini_cex_evaluation_params)
      redirect_to @mini_cex_evaluation, notice: "Evaluasi Mini-CEX diperbarui."
    else
      load_form_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @mini_cex_evaluation
    clinical_case = @mini_cex_evaluation.clinical_case
    @mini_cex_evaluation.destroy
    return redirect_to(clinical_case_path(clinical_case), notice: "Permintaan Mini-CEX dibatalkan.", status: :see_other) if clinical_case && @mini_cex_evaluation.student_id == current_user.id

    redirect_to assessments_path, notice: "Evaluasi Mini-CEX dihapus.", status: :see_other
  end

  def submit
    authorize @mini_cex_evaluation
    @mini_cex_evaluation.submit!
    redirect_to @mini_cex_evaluation, notice: "Evaluasi Mini-CEX dikirim ke mahasiswa."
  end

  def correction
    authorize @mini_cex_evaluation, :correct?
  end

  def create_correction
    authorize @mini_cex_evaluation, :correct?
    reason = params.require(:correction_reason).to_s.strip
    raise ArgumentError, "Alasan koreksi minimal 10 karakter." if reason.length < 10

    @correction = @mini_cex_evaluation.dup
    @correction.assign_attributes(status: "draft", evaluator: current_user,
      corrects: @mini_cex_evaluation, correction_reason: reason)
    @correction.save!
    redirect_to edit_mini_cex_evaluation_path(@correction), notice: "Draf koreksi dibuat. Evaluasi terkirim sebelumnya tetap menjadi riwayat."
  rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ActionController::ParameterMissing => error
    redirect_to mini_cex_evaluation_path(@mini_cex_evaluation), alert: error.message
  end

  private

  def require_wpba_enabled
    if action_name == "new"
      allowed = AssessmentAssignment.wpba_enabled_rotations_for(current_user).exists?
    else
      student = @mini_cex_evaluation&.student || student_for_submitted_rotation
      allowed = student.present? && ModuleConfiguration.for(student.study_program).enabled?("wpba")
    end
    return if allowed

    redirect_to assessments_path, alert: "Input WPBA untuk program studi ini sedang dinonaktifkan; riwayat tetap dapat dibaca."
  end

  def student_for_submitted_rotation
    rotation = ClinicalRotation.find_by(id: params.dig(:mini_cex_evaluation, :clinical_rotation_id))
    student_id = params.dig(:mini_cex_evaluation, :student_id)
    rotation.user if rotation && rotation.user_id.to_s == student_id.to_s
  end

  def set_mini_cex_evaluation
    @mini_cex_evaluation = MiniCexEvaluation.find(params[:id])
  end

  def load_form_collections
    @clinical_rotations = AssessmentAssignment.wpba_enabled_rotations_for(current_user).includes(:user).order(start_date: :desc)
    @students = User.active_accounts.where(id: @clinical_rotations.select(:user_id)).order(:full_name)
  end

  def mini_cex_evaluation_params
    permitted = params.require(:mini_cex_evaluation).permit(
      :student_id, :clinical_rotation_id, :case_description, :evaluated_at, :overall_feedback,
      :status, :global_rating, :clinical_setting, :patient_age_group, :case_complexity,
      :observation_minutes, :feedback_minutes, :video_recording_url,
      scores: MiniCexEvaluation::DIMENSIONS.keys
    )
    permitted[:scores] = permitted[:scores].to_h.compact_blank if permitted[:scores]
    permitted
  end
end
