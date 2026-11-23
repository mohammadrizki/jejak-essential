# frozen_string_literal: true

# Konfigurasi → Learning Unit: blok/modul dan Assessment Matrix-nya. Akses
# lintas program hanya tersedia bagi superadmin.
class Admin::LearningUnitsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_unit, only: %i[show edit update destroy add_mapping remove_mapping]

  def index
    @units = unit_scope.includes(:study_program, :academic_period, :assessment_mappings).ordered
  end

  def show
    @mappings = @unit.assessment_mappings.includes(:assessment_event)
    @available_events = event_scope.ordered.where.not(id: @mappings.map(&:assessment_event_id))
    students = User.active_accounts.joins(:roles).where(roles: { code: "mahasiswa" }).where(study_program_id: @unit.study_program_id).distinct.order(:full_name)
    @recap = students.map { |s| { student: s, score: @unit.score_for(s), components: @unit.components_for(s) } }
  end

  def new
    @unit = LearningUnit.new(academic_period: AcademicPeriod.ordered.first, study_program_id: managed_program_ids.first)
    load_collections
  end

  def create
    @unit = LearningUnit.new(unit_params)
    if permitted_program?(@unit.study_program) && @unit.save
      redirect_to admin_learning_unit_path(@unit), notice: "Learning Unit dibuat. Tambahkan komponen Assessment Matrix-nya."
    else
      @unit.errors.add(:study_program, "berada di luar cakupan program studi Anda") if @unit.errors.empty?
      load_collections
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_collections
  end

  def update
    attributes = unit_params
    if permitted_program?(StudyProgram.find_by(id: attributes[:study_program_id] || @unit.study_program_id)) && @unit.update(attributes)
      redirect_to admin_learning_unit_path(@unit), notice: "Learning Unit diperbarui."
    else
      @unit.errors.add(:study_program, "berada di luar cakupan program studi Anda") if @unit.errors.empty?
      load_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @unit.destroy
    redirect_to admin_learning_units_path, notice: "Learning Unit dihapus.", status: :see_other
  end

  def add_mapping
    mapping = @unit.assessment_mappings.new(assessment_event: event_scope.find_by(id: params[:assessment_event_id]), weight: params[:weight])
    if mapping.save
      redirect_to admin_learning_unit_path(@unit), notice: "Komponen ditambahkan (#{mapping.weight}%). Total bobot sekarang #{@unit.reload.total_weight.round(1)}%."
    else
      redirect_to admin_learning_unit_path(@unit), alert: mapping.errors.full_messages.to_sentence
    end
  end

  def remove_mapping
    @unit.assessment_mappings.find(params[:mapping_id]).destroy
    redirect_to admin_learning_unit_path(@unit), notice: "Komponen dihapus.", status: :see_other
  end

  private

  def require_admin!
    return if current_user.has_role?("superadmin") || current_user.programs_with_permission("curriculum.manage", "assessment.decide").any?

    redirect_to dashboard_path, alert: "Permission kurikulum atau asesmen pada program studi diperlukan."
  end

  def unit_scope
    current_user.has_role?("superadmin") ? LearningUnit.all : LearningUnit.where(study_program_id: managed_program_ids)
  end

  def event_scope
    current_user.has_role?("superadmin") ? AssessmentEvent.all : AssessmentEvent.where(study_program_id: managed_program_ids)
  end

  def set_unit
    @unit = unit_scope.find(params[:id])
  end

  def load_collections
    @study_programs = current_user.has_role?("superadmin") ? StudyProgram.ordered : StudyProgram.where(id: managed_program_ids).order(:name)
    @academic_periods = AcademicPeriod.ordered
    @blueprints = AssessmentBlueprint.where(study_program_id: managed_program_ids).order(:name)
  end

  def unit_params
    permitted = params.require(:learning_unit).permit(:name, :code, :study_program_id, :academic_period_id, :credits, :description, :assessment_blueprint_id)
    permitted
  end

  def managed_program_ids
    @managed_program_ids ||= current_user.has_role?("superadmin") ? StudyProgram.pluck(:id) : current_user.programs_with_permission("curriculum.manage", "assessment.decide").pluck(:id)
  end

  def permitted_program?(program)
    current_user.has_role?("superadmin") || current_user.permitted_for_program?(program, "curriculum.manage", "assessment.decide")
  end
end
