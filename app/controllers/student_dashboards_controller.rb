# frozen_string_literal: true

# Dasbor Mahasiswa (hanya-baca) bagi dosen/preseptor/kaprodi/admin: profil
# ringkas + Pusat Asesmen & Capaian milik mahasiswa itu. Tiap kartu membawa
# ?student_id= sehingga halaman asesmen menampilkan data mahasiswa tersebut
# (lihat ApplicationController#viewed_student).
class StudentDashboardsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_viewer!

  def show
    @student = User.find(params[:id])
    unless @student.has_role?("mahasiswa")
      redirect_to search_path(q: @student.email), alert: "#{@student.full_name} bukan mahasiswa."
      return
    end
    unless current_user.can_view_student?(@student)
      redirect_to search_path, alert: "#{@student.full_name} di luar program studi binaan Anda."
      return
    end

    @pending_count = @student.assessment_instances.awaiting_score.count
    @scored_count = @student.assessment_instances.scored.count
    @ongoing_rotation = @student.clinical_rotations.ongoing.first
    @activity_count = @student.activity_logs.count
    @verified_case_count = @student.clinical_cases.where(status: "verified").count
    @can_edit = current_user.has_role?("admin")
    @framework = @student.study_program&.peta_kompetensi
    @competency_attainments = if @framework
      @student.competency_attainments.where(competency_item_id: @framework.competency_items.select(:id))
        .includes(:decision_by).order(decision_date: :desc, id: :desc)
        .each_with_object({}) { |record, latest| latest[record.competency_item_id] ||= record }
    else
      {}
    end
    @can_decide_attainment = current_user.has_role?("admin") ||
      (current_user.instructor? && @student.supervised_by?(current_user))
  end

  private

  def require_viewer!
    return if current_user.can_view_students?

    redirect_to dashboard_path, alert: "Halaman ini untuk pengajar dan kaprodi."
  end
end
