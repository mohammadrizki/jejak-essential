# frozen_string_literal: true

# Form Builder generik — infrastruktur untuk asesmen yang bentuknya beda-beda
# per institusi (Tutor Evaluation, Evaluasi Blok, asesmen tambahan, Fase 10).
# BUKAN untuk DOPS/Mini-CEX (Fase 8) yang rubriknya baku secara internasional.
class AssessmentFormTemplate < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :study_program, optional: true
  has_many :assessment_form_fields, -> { order(:position) }, dependent: :destroy, inverse_of: :assessment_form_template
  has_many :assessment_form_submissions, dependent: :destroy

  validates :name, presence: true
  validate :kaprodi_template_has_program_scope
  validate :program_scope_is_immutable_after_use, if: :will_save_change_to_study_program_id?

  scope :active, -> { where(is_active: true) }

  private

  def kaprodi_template_has_program_scope
    return unless new_record?
    return if created_by.blank? || created_by.has_role?("admin") || !created_by.has_role?("kaprodi")
    return if study_program_id.present? && created_by.study_program_id == study_program_id

    errors.add(:study_program, "harus sesuai program studi Kaprodi pembuat formulir")
  end

  def program_scope_is_immutable_after_use
    return if new_record?
    return unless assessment_form_submissions.exists? || AssessmentEvent.exists?(assessment_form_template_id: id)

    errors.add(:study_program, "tidak dapat dipindahkan setelah formulir memiliki jawaban atau dipakai pada event asesmen")
  end
end
