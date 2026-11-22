# frozen_string_literal: true

class Admin::WpbaInstrumentsController < Admin::BaseController
  def index
    WpbaInstrumentCatalog.ensure_defaults!
    @instruments = WpbaInstrument.active.includes(:versions).order(:name)
  end

  def show
    @instrument = WpbaInstrument.includes(versions: :published_by).find(params[:id])
    @versions = @instrument.versions.order(created_at: :desc)
  end

  def new
    @instrument = WpbaInstrument.new
  end

  def create
    @instrument = WpbaInstrument.new(instrument_params)
    if @instrument.save
      redirect_to admin_wpba_instrument_path(@instrument), notice: "Instrumen WPBA dibuat. Tambahkan versi definisi sebelum digunakan."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def instrument_params
    params.require(:wpba_instrument).permit(:code, :name, :instrument_type).tap do |attributes|
      attributes[:instrument_type] = nil unless attributes[:instrument_type].in?(WpbaInstrument::CREATABLE_TYPES)
    end
  end
end
