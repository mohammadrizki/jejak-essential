# frozen_string_literal: true

class MiniCexEvaluationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_mini_cex_evaluation, only: %i[show edit update destroy submit]
  before_action :require_wpba_enabled, only: %i[new create edit update destroy submit]

  def show
    authorize @mini_cex_evaluation
  end

  def new
    authorize MiniCexEvaluation
    @mini_cex_evaluation = MiniCexEvaluation.new(evaluated_at: Date.current, evaluator: current_user)
    load_form_collections
  end

  def create
    authorize MiniCexEvaluation
    @mini_cex_evaluation = MiniCexEvaluation.new(mini_cex_evaluation_params)
    @mini_cex_evaluation.evaluator = current_user
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

  private

  def require_wpba_enabled
    return if ModuleConfiguration.for(current_user.study_program).enabled?("wpba")

    redirect_to assessments_path, alert: "Input WPBA untuk program studi ini sedang dinonaktifkan; riwayat tetap dapat dibaca."
  end

  def set_mini_cex_evaluation
    @mini_cex_evaluation = MiniCexEvaluation.find(params[:id])
  end

  def load_form_collections
    @clinical_rotations = AssessmentAssignment.rotations_for(current_user).includes(:user).order(start_date: :desc)
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
