# frozen_string_literal: true

class CompetencyIndicatorsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_competency_item
  before_action :set_indicator, only: %i[edit update destroy]

  def create
    authorize @competency_item.competency_framework, :update?
    indicator = @competency_item.competency_indicators.new(indicator_params)
    if indicator.save
      redirect_to competency_framework_path(@competency_item.competency_framework), notice: "Indikator kompetensi ditambahkan."
    else
      redirect_to competency_framework_path(@competency_item.competency_framework), alert: indicator.errors.full_messages.to_sentence
    end
  end

  def edit
    authorize @competency_item.competency_framework, :update?
  end

  def update
    authorize @competency_item.competency_framework, :update?
    if @indicator.update(indicator_params)
      redirect_to competency_framework_path(@competency_item.competency_framework), notice: "Indikator kompetensi diperbarui."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @competency_item.competency_framework, :update?
    if @indicator.destroy
      redirect_to competency_framework_path(@competency_item.competency_framework), notice: "Indikator kompetensi dihapus.", status: :see_other
    else
      redirect_to competency_framework_path(@competency_item.competency_framework), alert: @indicator.errors.full_messages.to_sentence
    end
  end

  private

  def set_competency_item
    @competency_item = CompetencyItem.find(params[:competency_item_id])
  end

  def set_indicator
    @indicator = @competency_item.competency_indicators.find(params[:id])
  end

  def indicator_params
    params.require(:competency_indicator).permit(:code, :description, :performance_level, :position, :is_active)
  end
end
