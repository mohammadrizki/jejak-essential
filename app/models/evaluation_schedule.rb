# frozen_string_literal: true

# Jadwal DOPS & Mini-CEX — rencana penilaian di tempat kerja per mahasiswa &
# penilai. Bukan evaluasinya sendiri: DOPS/Mini-CEX tetap dicatat lewat form
# masing-masing; jadwal ini yang ditandai "selesai".
class EvaluationSchedule < ApplicationRecord
  KINDS = { "dops" => "DOPS", "mini_cex" => "Mini-CEX" }.freeze
  STATUSES = { "planned" => "Terjadwal", "done" => "Selesai", "cancelled" => "Dibatalkan" }.freeze

  belongs_to :student, class_name: "User"
  belongs_to :evaluator, class_name: "User", optional: true
  belongs_to :clinical_rotation, optional: true
  belongs_to :assessment_event, optional: true

  validates :kind, inclusion: { in: KINDS.keys }
  validates :status, inclusion: { in: STATUSES.keys }
  validates :scheduled_at, presence: true
  validate :assessment_event_required_for_new_schedule
  validate :assessment_event_matches_schedule

  scope :upcoming, -> { where(status: "planned").where("scheduled_at >= ?", Time.current.beginning_of_day).order(:scheduled_at) }
  scope :for_user, ->(user) { where("student_id = :id OR evaluator_id = :id", id: user.id) }
  scope :ordered, -> { order(scheduled_at: :desc) }

  def kind_label = KINDS.fetch(kind, kind)
  def status_label = STATUSES.fetch(status, status)

  private

  def assessment_event_required_for_new_schedule
    errors.add(:assessment_event, "wajib dipilih dari Event Asesmen") if new_record? && assessment_event.blank?
  end

  def assessment_event_matches_schedule
    return if assessment_event.blank?

    expected_type = kind == "dops" ? "dops" : "mini_cex"
    errors.add(:assessment_event, "harus bertipe #{kind_label}") unless assessment_event.assessment_type == expected_type
    errors.add(:assessment_event, "sudah ditutup dan tidak menerima jadwal baru") if assessment_event.status == "closed"
    if student.present? && assessment_event.study_program_id.present? && assessment_event.study_program_id != student.study_program_id
      errors.add(:assessment_event, "harus berasal dari program studi mahasiswa")
    end
  end
end
