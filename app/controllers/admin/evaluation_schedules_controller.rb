# frozen_string_literal: true

# Jadwal DOPS & Mini-CEX — superadmin lintas prodi; pengelola berizin dibatasi
# ke program studi yang tercakup dalam permission assignments.manage.
class Admin::EvaluationSchedulesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_schedule, only: %i[edit update destroy]

  def index
    @schedules = schedule_scope.includes(:student, :evaluator, :clinical_rotation, :assessment_event).ordered.page(params[:page]).per(50)
  end

  def new
    @schedule = EvaluationSchedule.new(kind: "mini_cex", scheduled_at: 1.day.from_now.change(hour: 9))
    if params[:assessment_event_id].present?
      event = accessible_wpba_events.find(params[:assessment_event_id])
      @schedule.assessment_event = event
      @schedule.kind = event.assessment_type == "dops" ? "dops" : "mini_cex"
    end
    load_collections
    unless @assessment_events.any? || @students.map(&:study_program).compact.uniq.any? { |program| scheduling_enabled_for?(program) }
      redirect_to admin_evaluation_schedules_path, alert: "Penjadwalan Asesmen nonaktif pada program studi dalam cakupan Anda."
    end
  end

  def create
    @schedule = EvaluationSchedule.new(schedule_params)
    if scheduling_enabled_for?(@schedule.student&.study_program) && within_program_scope?(@schedule) && @schedule.save
      notify_parties
      redirect_to admin_evaluation_schedules_path, notice: "Jadwal #{@schedule.kind_label} dibuat."
    else
      @schedule.errors.add(:base, "Penjadwalan Asesmen dan WPBA harus aktif pada program studi mahasiswa.") unless scheduling_enabled_for?(@schedule.student&.study_program)
      load_collections
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    return redirect_to admin_evaluation_schedules_path, alert: "Modul penjadwalan nonaktif; jadwal ini hanya dapat dibaca." unless scheduling_enabled_for?(@schedule.student.study_program)

    load_collections
  end

  def update
    return redirect_to admin_evaluation_schedules_path, alert: "Modul penjadwalan nonaktif; jadwal ini hanya dapat dibaca." unless scheduling_enabled_for?(@schedule.student.study_program)

    @schedule.assign_attributes(schedule_params)
    if scheduling_enabled_for?(@schedule.student&.study_program) && within_program_scope?(@schedule) && @schedule.save
      redirect_to admin_evaluation_schedules_path, notice: "Jadwal diperbarui."
    else
      @schedule.errors.add(:base, "Penjadwalan Asesmen dan WPBA harus aktif pada program studi mahasiswa.") unless scheduling_enabled_for?(@schedule.student&.study_program)
      load_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    return redirect_to admin_evaluation_schedules_path, alert: "Modul penjadwalan nonaktif; jadwal historis dipertahankan." unless scheduling_enabled_for?(@schedule.student.study_program)

    @schedule.destroy
    redirect_to admin_evaluation_schedules_path, notice: "Jadwal dihapus.", status: :see_other
  end

  private

  def require_admin!
    return if current_user.has_role?("superadmin") || current_user.programs_with_permission("assignments.manage").any?

    redirect_to dashboard_path, alert: "Permission penugasan pada program studi diperlukan."
  end

  def student_scope
    students = User.active_accounts.joins(:roles).where(roles: { code: "mahasiswa" }).distinct
    current_user.has_role?("superadmin") ? students : students.where(study_program_id: managed_program_ids)
  end

  def schedule_scope
    return EvaluationSchedule.all if current_user.has_role?("superadmin")

    EvaluationSchedule.where(student_id: student_scope.select(:id))
  end

  def set_schedule
    @schedule = schedule_scope.find(params[:id])
  end

  # Mahasiswa (dan rotasinya) harus dalam cakupan prodi akun ini.
  def within_program_scope?(schedule)
    return true if current_user.has_role?("superadmin")

    schedule.errors.add(:student, "di luar cakupan program studi Anda") if schedule.student_id && !student_scope.exists?(schedule.student_id)
    rotation = schedule.clinical_rotation
    schedule.errors.add(:clinical_rotation, "bukan rotasi mahasiswa dalam cakupan Anda") if rotation && !student_scope.exists?(rotation.user_id)
    schedule.errors.add(:clinical_rotation, "harus dimiliki mahasiswa yang dijadwalkan") if rotation && schedule.student_id && rotation.user_id != schedule.student_id
    evaluator = schedule.evaluator
    schedule.errors.add(:evaluator, "harus berada pada program studi mahasiswa") if evaluator && evaluator.study_program_id != schedule.student&.study_program_id
    schedule.errors.none?
  end

  def load_collections
    @students = student_scope.order(:full_name)
    @evaluators = User.active_accounts.joins(:roles).where(roles: { code: %w[dosen preseptor] })
    @evaluators = @evaluators.where(study_program_id: managed_program_ids) unless current_user.has_role?("superadmin")
    @evaluators = @evaluators.distinct.order(:full_name)
    @rotations = ClinicalRotation.where(user_id: student_scope.select(:id)).includes(:user).order(start_date: :desc).limit(200)
    @assessment_events = accessible_wpba_events
  end

  def accessible_wpba_events
    events = AssessmentEvent.includes(:academic_period, :study_program).where(assessment_type: %w[dops mini_cex])
    events = events.where(study_program_id: managed_program_ids) unless current_user.has_role?("superadmin")
    events.where.not(status: "closed").ordered.to_a.select { |event| scheduling_enabled_for?(event.study_program) }
  end

  def scheduling_enabled_for?(program)
    program.present? && ModuleConfiguration.for(program).enabled?("assessment_scheduling") &&
      ModuleConfiguration.for(program).enabled?("wpba")
  end

  def managed_program_ids
    @managed_program_ids ||= current_user.has_role?("superadmin") ? StudyProgram.pluck(:id) : current_user.programs_with_permission("assignments.manage").pluck(:id)
  end

  def schedule_params
    params.require(:evaluation_schedule).permit(:kind, :student_id, :evaluator_id, :clinical_rotation_id,
      :assessment_event_id, :scheduled_at, :topic, :status, :notes)
  end

  def notify_parties
    [ @schedule.student, @schedule.evaluator ].compact.each do |u|
      Notification.notify!(recipient: u, notifiable: @schedule,
                           title: "Jadwal #{@schedule.kind_label} #{I18n.l(@schedule.scheduled_at, format: :short)}",
                           message: @schedule.topic.presence || "#{@schedule.student.full_name} · #{@schedule.evaluator&.full_name}")
    end
  end
end
