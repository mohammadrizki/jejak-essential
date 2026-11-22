# frozen_string_literal: true

class ReflectionEntriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_reflection_entry, only: %i[show edit update destroy]

  def index
    @reflection_entries = current_user.reflection_entries.recent.page(params[:page])
  end

  def show
  end

  def new
    @reflection_entry = current_user.reflection_entries.build(entry_date: Date.current)
    load_linkable_records
  end

  def create
    @reflection_entry = current_user.reflection_entries.build(reflection_entry_params)

    if @reflection_entry.save
      redirect_to @reflection_entry, notice: "Refleksi berhasil disimpan."
    else
      load_linkable_records
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_linkable_records
  end

  def update
    if @reflection_entry.update(reflection_entry_params)
      redirect_to @reflection_entry, notice: "Refleksi berhasil diperbarui."
    else
      load_linkable_records
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @reflection_entry.destroy
    redirect_to reflection_entries_path, notice: "Refleksi dihapus.", status: :see_other
  end

  private

  def set_reflection_entry
    @reflection_entry = current_user.reflection_entries.find(params[:id])
  end

  def load_linkable_records
    @activity_logs = current_user.activity_logs.recent.limit(20)
    @clinical_cases = current_user.clinical_cases.recent.limit(20)
    framework = current_user.study_program&.peta_kompetensi
    @competency_items = framework ? framework.competency_items.order(:position, :title) : CompetencyItem.none
    @evidence_sources = current_user.evidence_sources.order(occurred_on: :desc, id: :desc).limit(100)
  end

  def reflection_entry_params
    params.require(:reflection_entry).permit(:entry_date, :title, :content, :what_happened, :what_learned,
      :what_to_improve, :next_action, :activity_log_id, :clinical_case_id,
      competency_item_ids: [], evidence_source_ids: [])
  end
end
