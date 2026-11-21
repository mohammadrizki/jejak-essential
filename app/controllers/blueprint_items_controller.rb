# frozen_string_literal: true

class BlueprintItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_blueprint

  def create
    authorize @blueprint, :update?
    version = @blueprint.draft_version
    return redirect_to @blueprint, alert: "Buat versi draf sebelum mengubah komponen blueprint." if version.blank?

    attributes = blueprint_item_params
    competency_ids = Array(attributes.delete(:competency_item_ids)).reject(&:blank?)
    indicator_ids = Array(attributes.delete(:competency_indicator_ids)).reject(&:blank?)
    epa_ids = Array(attributes.delete(:epa_ids)).reject(&:blank?)
    epa_purpose = attributes.delete(:epa_purpose).presence || "formative"
    epa_expected_level = attributes.delete(:epa_expected_level).presence
    epa_supervision_level_id = attributes.delete(:epa_supervision_level_id).presence
    epa_supervision_level = SupervisionLevel.find(epa_supervision_level_id) if epa_supervision_level_id
    target_expected_level = if epa_supervision_level
      epa_supervision_level.ordinal <= 5 ? epa_supervision_level.ordinal : nil
    else
      epa_expected_level
    end
    item = version.blueprint_items.new(attributes)
    ActiveRecord::Base.transaction do
      item.save!
      competency_ids.each do |id|
        item.blueprint_item_competencies.create!(competency_item: version.competency_framework.competency_items.find(id))
      end
      indicator_ids.each do |id|
        indicator = version.competency_framework.competency_indicators.find(id)
        item.blueprint_item_competencies.create!(competency_item: indicator.competency_item, competency_indicator: indicator)
      end
      epa_ids.each do |id|
        item.blueprint_item_epas.create!(epa: version.competency_framework.epas.find(id),
          assessment_purpose: epa_purpose, expected_level: target_expected_level,
          supervision_level: epa_supervision_level)
      end
    end
    redirect_to @blueprint, notice: "Komponen asesmen ditambahkan ke versi draf."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    redirect_to @blueprint, alert: e.message
  end

  def destroy
    authorize @blueprint, :update?
    item = @blueprint.draft_version&.blueprint_items&.find(params[:id])
    return redirect_to @blueprint, alert: "Komponen hanya dapat dihapus dari versi draf." if item.blank?

    item.destroy!
    redirect_to @blueprint, notice: "Komponen asesmen dihapus dari draf."
  rescue ActiveRecord::RecordNotDestroyed => e
    redirect_to @blueprint, alert: e.record.errors.full_messages.to_sentence
  end

  private

  def set_blueprint
    @blueprint = AssessmentBlueprint.find(params[:assessment_blueprint_id])
  end

  def blueprint_item_params
    params.require(:blueprint_item).permit(:assessment_method_id, :code, :title, :assessment_context,
      :target_count, :weight, :frequency, :curricular_stage, :minimum_standard,
      :epa_purpose, :epa_expected_level, :epa_supervision_level_id,
      competency_item_ids: [], competency_indicator_ids: [], epa_ids: [])
  end
end
