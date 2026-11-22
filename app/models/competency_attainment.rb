# frozen_string_literal: true

class CompetencyAttainment < ApplicationRecord
  STATUSES = %w[proposed approved rejected].freeze

  belongs_to :student, class_name: "User"
  belongs_to :competency_item
  belongs_to :decision_by, class_name: "User", optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true
  has_many :reviews, class_name: "CompetencyAttainmentReview", dependent: :restrict_with_error

  validates :decision_date, presence: true
  validates :attainment_level, inclusion: { in: 1..5 }, allow_nil: true
  validates :status, inclusion: { in: STATUSES }
  validates :rationale, presence: true, length: { minimum: 10 }
  validate :competency_belongs_to_student_program
  validate :review_decision_is_consistent
  before_update :final_decision_is_immutable

  def review!(by:, decision:, notes:)
    raise ArgumentError, "Keputusan telaah tidak dikenal." unless %w[approved rejected].include?(decision)
    raise ArgumentError, "Usulan sudah ditelaah." unless status == "proposed"
    raise ArgumentError, "Catatan telaah minimal 10 karakter." if notes.to_s.strip.length < 10

    self.class.transaction do
      reviews.create!(reviewer: by, decision: decision, notes: notes.to_s.strip, reviewed_at: Time.current)
      update!(status: decision, reviewed_by: by, reviewed_at: Time.current, review_notes: notes.to_s.strip)
    end
  end

  private

  def competency_belongs_to_student_program
    return if student&.study_program_id.present? && competency_item&.competency_framework&.study_program_id == student.study_program_id

    errors.add(:competency_item, "harus berasal dari framework program studi mahasiswa")
  end

  def review_decision_is_consistent
    return if status == "proposed"
    return if reviewed_by_id.present? && reviewed_at.present? && review_notes.present?

    errors.add(:reviewed_by, "keputusan final harus memiliki reviewer, waktu, dan catatan")
  end

  def final_decision_is_immutable
    return if status_in_database == "proposed"

    errors.add(:base, "Keputusan capaian final bersifat historis; buat keputusan baru untuk perubahan.")
    throw(:abort)
  end
end
