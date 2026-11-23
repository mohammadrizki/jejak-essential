# frozen_string_literal: true

# Sunting satu percobaan dari halaman event: penguji, jadwal, nilai manual.
class Admin::AssessmentInstancesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_assessment_manager!
  before_action :set_instance
  before_action :authorize_event_program!

  def update
    attrs = params.require(:assessment_instance).permit(:examiner_id, :scheduled_at, :score, :max_score, :feedback_keep, :feedback_improve)
    examiner = User.active_accounts.find_by(id: attrs[:examiner_id]) if attrs[:examiner_id].present?
    if attrs[:examiner_id].present? && examiner.nil?
      return redirect_to admin_assessment_event_path(@instance.assessment_event), alert: "Penguji tidak ditemukan."
    end
    if examiner && !current_user.has_role?("superadmin") && examiner.study_program_id != @instance.assessment_event.study_program_id
      return redirect_to admin_assessment_event_path(@instance.assessment_event), alert: "Penguji berada di luar cakupan program studi event."
    end
    if attrs[:score].present?
      @instance.assign_attributes(attrs.merge(examiner: examiner || @instance.examiner, status: "scored", scored_at: Time.current, source: "manual"))
    else
      @instance.assign_attributes(attrs.except(:score).merge(examiner: examiner || @instance.examiner))
    end

    if @instance.save
      redirect_to admin_assessment_event_path(@instance.assessment_event), notice: "Percobaan #{@instance.student.full_name} diperbarui."
    else
      redirect_to admin_assessment_event_path(@instance.assessment_event), alert: @instance.errors.full_messages.to_sentence
    end
  end

  def destroy
    event = @instance.assessment_event
    @instance.destroy
    redirect_to admin_assessment_event_path(event), notice: "Percobaan dihapus.", status: :see_other
  end

  private

  def require_assessment_manager!
    return if current_user.has_role?("superadmin") || current_user.programs_with_permission("assessment.decide").any?

    redirect_to dashboard_path, alert: "Hak kelola asesmen pada program studi diperlukan."
  end

  def set_instance
    @instance = AssessmentInstance.joins(:assessment_event)
      .where(assessment_events: { study_program_id: permitted_program_ids })
      .find(params[:id]) unless current_user.has_role?("superadmin")
    @instance ||= AssessmentInstance.find(params[:id])
  end

  def authorize_event_program!
    program = @instance.assessment_event.study_program
    return if current_user.has_role?("superadmin") || current_user.permitted_for_program?(program, "assessment.decide")

    redirect_to dashboard_path, alert: "Percobaan asesmen berada di luar cakupan program studi Anda."
  end

  def permitted_program_ids
    current_user.programs_with_permission("assessment.decide").pluck(:id)
  end
end
