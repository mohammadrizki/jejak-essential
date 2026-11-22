# frozen_string_literal: true

class Admin::WpbaInstrumentVersionsController < Admin::BaseController
  before_action :set_instrument

  def create
    @version = @instrument.versions.new(version_label: params.dig(:version, :version_label),
      definition: JSON.parse(params.dig(:version, :definition_json).to_s))
    if @version.save
      redirect_to admin_wpba_instrument_path(@instrument), notice: "Versi instrumen ditambahkan sebagai draf."
    else
      redirect_to admin_wpba_instrument_path(@instrument), alert: @version.errors.full_messages.to_sentence
    end
  rescue JSON::ParserError
    redirect_to admin_wpba_instrument_path(@instrument), alert: "Definisi harus berupa JSON yang valid."
  end

  def publish
    version = @instrument.versions.find(params[:id])
    version.publish!(by: current_user)
    redirect_to admin_wpba_instrument_path(@instrument), notice: "Versi instrumen diterbitkan dan siap dipakai untuk asesmen baru."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to admin_wpba_instrument_path(@instrument), alert: error.message
  end

  private

  def set_instrument
    @instrument = WpbaInstrument.find(params[:wpba_instrument_id])
  end
end
