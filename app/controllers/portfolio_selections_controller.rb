# frozen_string_literal: true

class PortfolioSelectionsController < ApplicationController
  before_action :authenticate_user!

  def create
    submission = current_user.artifact_submissions.find(params[:artifact_submission_id])
    @selection = submission.build_portfolio_selection(student: current_user, selected_at: Time.current,
      visibility: selection_params[:visibility])
    authorize @selection
    if @selection.save
      redirect_to portfolio_path, notice: "Artefak masuk ke Portofolio Terpilih."
    else
      redirect_to portfolio_path, alert: @selection.errors.full_messages.to_sentence
    end
  end

  def destroy
    @selection = current_user.portfolio_selections.find(params[:id])
    authorize @selection
    @selection.destroy!
    redirect_to portfolio_path, notice: "Artefak dihapus dari Portofolio Terpilih."
  end

  def show
    @student = User.active_accounts.find(params[:student_id])
    @selections = @student.portfolio_selections.includes(artifact_submission: :reviewer)
      .where(visibility: "assigned_reviewers").order(selected_at: :desc)
    authorize PortfolioSelection.new(student: @student), :show_student?
  end

  private

  def selection_params
    params.require(:portfolio_selection).permit(:visibility)
  end
end
