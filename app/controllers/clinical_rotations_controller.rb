# frozen_string_literal: true

class ClinicalRotationsController < ApplicationController
  include PlacementCsvImportActions

  before_action :authenticate_user!
  before_action :set_clinical_rotation, only: %i[edit update destroy]

  def index
    @rotations = policy_scope(ClinicalRotation).includes(:academic_period, :preceptor, :user).order(start_date: :desc)
                                              .page(params[:page]).per(50)
  end

  def new
    authorize ClinicalRotation
    @clinical_rotation = ClinicalRotation.new
    load_form_collections
  end

  def create
    authorize ClinicalRotation
    @clinical_rotation = ClinicalRotation.new(clinical_rotation_params)
    authorize @clinical_rotation, :create?

    if within_program_scope?(@clinical_rotation) && @clinical_rotation.save
      redirect_to clinical_rotations_path, notice: "Rotasi berhasil ditambahkan."
    else
      load_form_collections
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @clinical_rotation
    load_form_collections
  end

  def update
    authorize @clinical_rotation
    @clinical_rotation.assign_attributes(clinical_rotation_params)
    if within_program_scope?(@clinical_rotation) && @clinical_rotation.save
      redirect_to clinical_rotations_path, notice: "Rotasi berhasil diperbarui."
    else
      load_form_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @clinical_rotation
    if @clinical_rotation.destroy
      redirect_to clinical_rotations_path, notice: "Rotasi dihapus.", status: :see_other
    else
      redirect_to clinical_rotations_path, status: :see_other,
                  alert: "Rotasi #{@clinical_rotation.station_name} tidak dapat dihapus karena sudah punya penilaian DOPS/Mini-CEX."
    end
  end

  private

  def placement_model = ClinicalRotation
  def placement_importer = ClinicalRotationCsvImport
  def import_success_path = clinical_rotations_path

  def load_form_collections
    program_ids = current_user.has_role?("superadmin") ? StudyProgram.select(:id) : current_user.programs_with_permission("assignments.manage").select(:id)
    @students = User.active_accounts.joins(:roles).where(roles: { code: "mahasiswa" }, study_program_id: program_ids).distinct.order(:full_name)
    # Preseptor rotasi: peran Preseptor (pembimbing klinik) dan Dosen. Dulu
    # hanya Dosen, sehingga akun berperan Preseptor tidak dapat dipilih.
    @preceptors = User.active_accounts.joins(:roles).where(roles: { code: %w[preseptor dosen] }, study_program_id: program_ids).distinct.order(:full_name)
    @academic_periods = AcademicPeriod.ordered
  end

  def clinical_rotation_params
    params.require(:clinical_rotation).permit(
      :user_id, :academic_period_id, :preceptor_id, :station_name, :institution_name, :start_date, :end_date
    )
  end

  def within_program_scope?(rotation)
    return true if current_user.has_role?("superadmin")

    allowed = current_user.permitted_for_program?(rotation.user&.study_program, "assignments.manage")
    preceptor_matches = rotation.preceptor.blank? || rotation.preceptor.study_program_id == rotation.user&.study_program_id
    rotation.errors.add(:user, "berada di luar cakupan program studi Anda") unless allowed
    rotation.errors.add(:preceptor, "harus berada pada program studi mahasiswa") unless preceptor_matches
    allowed && preceptor_matches
  end

  def set_clinical_rotation
    @clinical_rotation = policy_scope(ClinicalRotation).find(params[:id])
  end
end
