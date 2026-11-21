# frozen_string_literal: true

# Peta EPA & Tingkat Entrustment (/dashboard/entrustment):
# mahasiswa melihat levelnya per ranah; pembimbing (tutor/preseptor/dosen/
# admin yang punya relasi) mengisi/memperbarui dengan justifikasi naratif.
class EntrustmentDecisionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_student

  def index
    @framework = CompetencyFramework.for_student(@student)
    @map = @framework ? EntrustmentDecision.map_for(@student, @framework) : []
    @history = EntrustmentDecision.where(student: @student).includes(:competency_item, :decided_by, :clinical_case).history.limit(30)
    @can_decide = can_decide?
  end

  def create
    redirect_to entrustment_decisions_path(student_id: @student.id),
      alert: "Keputusan entrustment dibuat melalui tinjauan Otoritas Akademik. Catat penilaian formatif sebagai observasi EPA."
  end

  private

  # Mahasiswa hanya peta miliknya; pengajar & kaprodi (prodi binaannya saja)
  # boleh membuka mahasiswa lain — kaprodi hanya melihat, lihat can_decide?.
  def set_student
    @student = viewed_student
  end

  def can_decide?
    return false if @student == current_user
    return true if current_user.has_role?("admin")
    return false unless current_user.instructor?

    @student.tutorial_enrollments.active.exists?(tutor: current_user) ||
      @student.clinical_rotations.ongoing.exists?(preceptor: current_user) ||
      @student.supervised_by?(current_user)
  end
end
