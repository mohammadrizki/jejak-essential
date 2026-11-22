# frozen_string_literal: true

class CompetencyAttainmentsController < ApplicationController
  before_action :authenticate_user!

  def create
    student = User.find(params[:student_id])
    unless AssignmentAuthorization.assigned?(user: current_user, role: "competency_attainment_proposer", student: student)
      return redirect_to student_dashboard_path(student), alert: "Anda tidak memiliki penugasan untuk mengusulkan capaian kompetensi."
    end

    framework = student.study_program&.peta_kompetensi
    item = framework&.competency_items&.find(params[:competency_item_id])
    attainment = CompetencyAttainment.create!(
      student: student, competency_item: item, decision_by: current_user,
      attainment_level: params[:attainment_level].to_i,
      decision_date: Time.current, status: "proposed",
      framework_version: framework.version,
      evidence_snapshot: CompetencyAttainmentSnapshot.capture(student: student, competency_item: item),
      rationale: params[:rationale].to_s.strip
    )
    redirect_to student_dashboard_path(student), notice: "Usulan capaian #{item.title} dicatat menunggu Otoritas Akademik."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to student_dashboard_path(student), alert: e.record.errors.full_messages.to_sentence
  rescue ActiveRecord::RecordNotFound
    redirect_to student_dashboard_path(student), alert: "Kompetensi tidak ditemukan pada framework mahasiswa."
  end

  def review
    student = User.find(params[:student_id])
    attainment = student.competency_attainments.find(params[:id])
    unless AssignmentAuthorization.assigned?(user: current_user, role: "competency_attainment_decider", student: student)
      return redirect_to student_dashboard_path(student), alert: "Anda tidak memiliki penugasan untuk memutuskan capaian kompetensi."
    end

    attainment.review!(by: current_user, decision: params[:decision], notes: params[:review_notes])
    redirect_to student_dashboard_path(student), notice: "Keputusan capaian kompetensi tersimpan."
  rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => error
    redirect_to student_dashboard_path(params[:student_id]), alert: error.message
  end

  private

end
