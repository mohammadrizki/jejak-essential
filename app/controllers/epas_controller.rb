# frozen_string_literal: true

class EpasController < ApplicationController
  before_action :authenticate_user!
  before_action :set_framework

  def create
    authorize @framework, :update?
    return redirect_to @framework, alert: "EPA hanya berlaku untuk tahap Profesi, Spesialis, dan Subspesialis." if @framework.education_stage == "undergraduate"

    attributes = epa_params
    competency_item_ids = Array(attributes.delete(:competency_item_ids)).reject(&:blank?)
    epa = @framework.epas.new(attributes.merge(status: "published"))
    saved = ActiveRecord::Base.transaction do
      epa.save! && competency_item_ids.each { |id| epa.epa_competencies.create!(competency_item: @framework.competency_items.find(id)) }
      true
    end
    if saved
      redirect_to @framework, notice: "EPA ditambahkan ke versi framework ini."
    else
      redirect_to @framework, alert: epa.errors.full_messages.to_sentence
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    redirect_to @framework, alert: e.message
  end

  def destroy
    authorize @framework, :update?
    epa = @framework.epas.find(params[:id])
    if epa.destroy
      redirect_to @framework, notice: "EPA dihapus.", status: :see_other
    else
      redirect_to @framework, alert: epa.errors.full_messages.to_sentence
    end
  end

  def map_competency
    authorize @framework, :update?
    epa = @framework.epas.find(params[:id])
    return redirect_to @framework, alert: "Buat versi draf sebelum mengubah pemetaan EPA." unless @framework.status == "draft"

    attributes = params.require(:epa_competency).permit(:competency_item_id, :competency_indicator_id,
      :contribution, :importance_weight, :notes, :ksa_dimension, :is_prerequisite,
      :minimum_attainment_level, :is_critical)
    item = @framework.competency_items.find(attributes.delete(:competency_item_id))
    indicator_id = attributes.delete(:competency_indicator_id).presence
    indicator = indicator_id && @framework.competency_indicators.find(indicator_id)
    epa.epa_competencies.create!(attributes.merge(competency_item: item, competency_indicator: indicator))
    redirect_to @framework, notice: "Pemetaan kompetensi/prasyarat KSA ditambahkan ke EPA."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => error
    redirect_to @framework, alert: error.message
  end

  private

  def set_framework
    @framework = CompetencyFramework.find(params[:competency_framework_id])
  end

  def epa_params
    params.require(:epa).permit(:code, :title, :description, :scope, :limitations, :risk_level, competency_item_ids: [])
  end
end
