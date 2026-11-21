# frozen_string_literal: true

class CompetencyAttainment < ApplicationRecord
  STATUSES = %w[proposed approved rejected].freeze

  belongs_to :student, class_name: "User"
  belongs_to :competency_item
  belongs_to :decision_by, class_name: "User", optional: true

  validates :decision_date, presence: true
  validates :attainment_level, inclusion: { in: 1..5 }, allow_nil: true
  validates :status, inclusion: { in: STATUSES }
  validates :rationale, presence: true, length: { minimum: 10 }
  validate :competency_belongs_to_student_program

  private

  def competency_belongs_to_student_program
    return if student&.study_program_id.present? && competency_item&.competency_framework&.study_program_id == student.study_program_id

    errors.add(:competency_item, "harus berasal dari framework program studi mahasiswa")
  end
end
