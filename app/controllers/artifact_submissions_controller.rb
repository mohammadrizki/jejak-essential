# frozen_string_literal: true

class ArtifactSubmissionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_submission, only: %i[update destroy resubmit]

  def index
    authorize ArtifactSubmission
    @submissions = policy_scope(ArtifactSubmission).includes(:student, :reviewer, :portfolio_selection)
      .where(status: %w[submitted approved rejected]).order(submitted_at: :desc)
    @submissions = @submissions.where(status: "submitted")
  end

  def create
    source_type, source_id = submission_params[:source_reference].to_s.split(":", 2)
    @submission = ArtifactSubmission.new(
      student: current_user, source_type: source_type,
      source_id: source_id, selection_reason: submission_params[:selection_reason],
      reflection: submission_params[:reflection], status: "submitted", submitted_at: Time.current
    )
    authorize @submission
    if @submission.save
      redirect_to portfolio_path, notice: "Artefak diajukan untuk ditelaah."
    else
      redirect_to portfolio_path, alert: @submission.errors.full_messages.to_sentence
    end
  end

  def update
    authorize @submission
    @submission.review!(by: current_user, decision: params[:decision], notes: params[:review_notes])
    redirect_to artifact_submissions_path, notice: "Hasil telaah artefak tersimpan."
  rescue ArgumentError, ActiveRecord::RecordInvalid => error
    redirect_to artifact_submissions_path, alert: error.message
  end

  def destroy
    authorize @submission
    @submission.update!(status: "withdrawn")
    redirect_to portfolio_path, notice: "Pengajuan artefak ditarik."
  end

  def resubmit
    authorize @submission, :resubmit?
    @submission.resubmit!
    redirect_to portfolio_path, notice: "Artefak diajukan ulang; riwayat telaah sebelumnya tetap tersimpan."
  rescue ArgumentError, ActiveRecord::RecordInvalid => error
    redirect_to portfolio_path, alert: error.message
  end

  private

  def set_submission
    @submission = ArtifactSubmission.find(params[:id])
  end

  def submission_params
    params.require(:artifact_submission).permit(:source_reference, :selection_reason, :reflection)
  end
end
