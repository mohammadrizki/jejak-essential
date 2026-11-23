# frozen_string_literal: true

class EpaMilestonesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_framework_and_epa

  def create
    authorize @framework, :update?
    return unless require_epa_module!

    return redirect_to @framework, alert: "Buat versi draf sebelum mengubah target EPA." unless @framework.status == "draft"

    level = SupervisionLevel.joins(:supervision_scale_version)
      .where(supervision_scale_versions: { use_case: "prospective_entrustment", active: true })
      .find(params.require(:epa_milestone).fetch(:supervision_level_id))
    @epa.epa_milestones.create!(milestone_params.merge(supervision_level: level, expected_level: level.ordinal))
    redirect_to @framework, notice: "Target supervisi jenjang ditambahkan."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => error
    redirect_to @framework, alert: error.message
  end

  def destroy
    authorize @framework, :update?
    return unless require_epa_module!

    return redirect_to @framework, alert: "Buat versi draf sebelum menghapus target EPA." unless @framework.status == "draft"

    @epa.epa_milestones.find(params[:id]).destroy!
    redirect_to @framework, notice: "Target supervisi EPA dihapus."
  rescue ActiveRecord::RecordNotDestroyed => error
    redirect_to @framework, alert: error.record.errors.full_messages.to_sentence
  end

  private

  def set_framework_and_epa
    @framework = CompetencyFramework.find(params[:competency_framework_id])
    @epa = @framework.epas.find(params[:epa_id])
  end

  def require_epa_module!
    return true if ModuleConfiguration.for(@framework.study_program).enabled?("epa")

    redirect_to @framework, alert: "Modul EPA tidak aktif untuk program studi ini. Aktifkan modul sebelum mengelola target EPA."
    false
  end

  def milestone_params
    params.require(:epa_milestone).permit(:stage, :notes)
  end
end
