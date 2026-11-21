# frozen_string_literal: true

class CompetencyAttainmentsController < ApplicationController
  before_action :authenticate_user!

  def create
    student = User.find(params[:student_id])
    unless can_decide_for?(student)
      return redirect_to student_dashboard_path(student), alert: "Anda tidak memiliki relasi pembimbingan untuk mencatat pencapaian kompetensi."
    end

    framework = student.study_program&.peta_kompetensi
    item = framework&.competency_items&.find(params[:competency_item_id])
    attainment = CompetencyAttainment.create!(
      student: student, competency_item: item, decision_by: current_user,
      attainment_level: params[:attainment_level].to_i,
      decision_date: Time.current, status: current_user.has_role?("admin") ? "approved" : "proposed",
      rationale: params[:rationale].to_s.strip
    )
    redirect_to student_dashboard_path(student), notice: "Keputusan pencapaian #{item.title} disimpan sebagai #{attainment.status}."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to student_dashboard_path(student), alert: e.record.errors.full_messages.to_sentence
  rescue ActiveRecord::RecordNotFound
    redirect_to student_dashboard_path(student), alert: "Kompetensi tidak ditemukan pada framework mahasiswa."
  end

  private

  def can_decide_for?(student)
    return false if student == current_user
    return true if current_user.has_role?("admin")
    return false unless current_user.instructor?

    student.supervised_by?(current_user)
  end
end
