# frozen_string_literal: true

class DopsEvaluationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_dops_evaluation, only: %i[show edit update destroy submit]
  before_action :require_wpba_enabled, only: %i[new create edit update destroy submit]

  def show
    authorize @dops_evaluation
  end

  def new
    authorize DopsEvaluation
    @dops_evaluation = DopsEvaluation.new(evaluated_at: Date.current, evaluator: current_user)
    load_form_collections
  end

  def create
    authorize DopsEvaluation
    @dops_evaluation = DopsEvaluation.new(dops_evaluation_params)
    @dops_evaluation.evaluator = current_user
    authorize @dops_evaluation, :create_for_assigned_student?

    if @dops_evaluation.save
      redirect_to @dops_evaluation, notice: "Evaluasi DOPS berhasil disimpan."
    else
      load_form_collections
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @dops_evaluation
    load_form_collections
  end

  def update
    authorize @dops_evaluation
    if @dops_evaluation.update(dops_evaluation_params)
      redirect_to @dops_evaluation, notice: "Evaluasi DOPS diperbarui."
    else
      load_form_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @dops_evaluation
    clinical_case = @dops_evaluation.clinical_case
    @dops_evaluation.destroy
    return redirect_to(clinical_case_path(clinical_case), notice: "Permintaan DOPS dibatalkan.", status: :see_other) if clinical_case && @dops_evaluation.student_id == current_user.id

    redirect_to assessments_path, notice: "Evaluasi DOPS dihapus.", status: :see_other
  end

  def submit
    authorize @dops_evaluation
    @dops_evaluation.submit!
    redirect_to @dops_evaluation, notice: "Evaluasi DOPS dikirim ke mahasiswa."
  end

  private

  def require_wpba_enabled
    return if ModuleConfiguration.for(current_user.study_program).enabled?("wpba")

    redirect_to assessments_path, alert: "Input WPBA untuk program studi ini sedang dinonaktifkan; riwayat tetap dapat dibaca."
  end

  def set_dops_evaluation
    @dops_evaluation = DopsEvaluation.find(params[:id])
  end

  def load_form_collections
    @clinical_rotations = AssessmentAssignment.rotations_for(current_user).includes(:user).order(start_date: :desc)
    @students = User.active_accounts.where(id: @clinical_rotations.select(:user_id)).order(:full_name)
  end

  def dops_evaluation_params
    permitted = params.require(:dops_evaluation).permit(
      :student_id, :clinical_rotation_id, :procedure_name, :evaluated_at, :overall_feedback,
      :status, :clinical_setting, :patient_age_group, :case_complexity,
      :observation_minutes, :feedback_minutes, :video_recording_url,
      scores: DopsEvaluation::DIMENSIONS.keys
    )
    permitted[:scores] = permitted[:scores].to_h.compact_blank if permitted[:scores]
    permitted
  end
end
