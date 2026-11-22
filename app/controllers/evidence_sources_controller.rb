# frozen_string_literal: true

class EvidenceSourcesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_source, only: %i[validate reject]

  def index
    @sources = policy_scope(EvidenceSource).includes(:student, :assessor,
      evidence_records: { evidence_requirement: %i[competency_indicator competency_item epa] })
      .order(occurred_on: :desc, id: :desc)
    authorize EvidenceSource
  end

  def validate
    authorize @source
    @source.validate_source!(by: current_user)
    redirect_to evidence_sources_path, notice: "Bukti eksternal telah divalidasi dan dapat dinilai sesuai Syarat Bukti."
  rescue ActiveRecord::RecordInvalid, ArgumentError => error
    redirect_to evidence_sources_path, alert: error.message
  end

  def reject
    authorize @source, :reject?
    @source.reject_source!(by: current_user, reason: params.require(:reason))
    redirect_to evidence_sources_path, notice: "Bukti eksternal ditolak; alasan dan provenance tetap tersimpan."
  rescue ActiveRecord::RecordInvalid, ActionController::ParameterMissing, ArgumentError => error
    redirect_to evidence_sources_path, alert: error.message
  end

  private

  def set_source
    @source = EvidenceSource.find(params[:id])
  end
end
