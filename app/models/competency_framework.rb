# frozen_string_literal: true

class CompetencyFramework < ApplicationRecord
  belongs_to :study_program
  has_many :epa_programs, class_name: "StudyProgram", foreign_key: :competency_framework_id, dependent: :nullify
  has_many :competency_items, -> { order(:position) }, dependent: :destroy, inverse_of: :competency_framework
  # Diperiksa sebelum simpul-simpulnya dihapus (lihat CompetencyItem).
  before_destroy :ensure_unused_by_entrustment, prepend: true

  validates :name, presence: true

  # Peta kompetensi utama milik program studi mahasiswa.
  def self.for_student(student)
    student&.study_program&.peta_kompetensi
  end

  def domains
    competency_items.where(parent_id: nil)
  end

  private

  def ensure_unused_by_entrustment
    return unless EntrustmentDecision.exists?(competency_item_id: competency_items.select(:id))

    errors.add(:base, "sudah dipakai pada keputusan entrustment (Peta EPA) mahasiswa")
    throw :abort
  end
end
