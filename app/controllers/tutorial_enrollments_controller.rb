# frozen_string_literal: true

class TutorialEnrollmentsController < ApplicationController
  include PlacementCsvImportActions

  before_action :authenticate_user!
  before_action :set_enrollment, only: %i[edit update destroy toggle_active]

  def index
    @enrollments = policy_scope(TutorialEnrollment).includes(:academic_period, :tutor, :user).ordered
                                                   .page(params[:page]).per(50)
  end

  def new
    authorize TutorialEnrollment
    @enrollment = TutorialEnrollment.new(academic_period: AcademicPeriod.ordered.first)
    load_form_collections
  end

  def create
    authorize TutorialEnrollment
    @enrollment = TutorialEnrollment.new(enrollment_params)
    authorize @enrollment, :create?

    if within_program_scope?(@enrollment) && @enrollment.save
      redirect_to tutorial_enrollments_path, notice: "Enrolment tutorial berhasil ditambahkan."
    else
      load_form_collections
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @enrollment
    load_form_collections
  end

  def update
    authorize @enrollment
    @enrollment.assign_attributes(enrollment_params)
    if within_program_scope?(@enrollment) && @enrollment.save
      redirect_to tutorial_enrollments_path, notice: "Enrolment tutorial berhasil diperbarui."
    else
      load_form_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def toggle_active
    authorize @enrollment, :update?
    @enrollment.update!(active: !@enrollment.active)
    redirect_to tutorial_enrollments_path, notice: "Enrolment ditandai #{@enrollment.status_label.downcase}.", status: :see_other
  end

  def destroy
    authorize @enrollment
    @enrollment.destroy
    redirect_to tutorial_enrollments_path, notice: "Enrolment tutorial dihapus.", status: :see_other
  end

  private

  def placement_model = TutorialEnrollment
  def placement_importer = TutorialEnrollmentCsvImport
  def import_success_path = tutorial_enrollments_path

  def set_enrollment
    @enrollment = TutorialEnrollment.find(params[:id])
  end

  def load_form_collections
    program_ids = current_user.has_role?("superadmin") ? StudyProgram.select(:id) : current_user.programs_with_permission("assignments.manage").select(:id)
    @students = User.active_accounts.joins(:roles).where(roles: { code: "mahasiswa" }, study_program_id: program_ids).distinct.order(:full_name)
    @tutors = User.active_accounts.joins(:roles).where(roles: { code: "dosen" }, study_program_id: program_ids).distinct.order(:full_name)
    @academic_periods = AcademicPeriod.ordered
  end

  def enrollment_params
    params.require(:tutorial_enrollment).permit(
      :user_id, :tutor_id, :academic_period_id, :block_name, :group_name, :start_date, :end_date, :active
    )
  end

  def within_program_scope?(enrollment)
    return true if current_user.has_role?("superadmin")

    allowed = current_user.permitted_for_program?(enrollment.user&.study_program, "assignments.manage")
    tutor_matches = enrollment.tutor.blank? || enrollment.tutor.study_program_id == enrollment.user&.study_program_id
    enrollment.errors.add(:user, "berada di luar cakupan program studi Anda") unless allowed
    enrollment.errors.add(:tutor, "harus berada pada program studi mahasiswa") unless tutor_matches
    allowed && tutor_matches
  end

  def set_enrollment
    @enrollment = policy_scope(TutorialEnrollment).find(params[:id])
  end
end
