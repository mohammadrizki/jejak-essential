# frozen_string_literal: true

class ReflectionEntryEvidenceSource < ApplicationRecord
  belongs_to :reflection_entry
  belongs_to :evidence_source

  validates :evidence_source_id, uniqueness: { scope: :reflection_entry_id }
  validate :evidence_source_belongs_to_reflection_owner

  private

  def evidence_source_belongs_to_reflection_owner
    return if reflection_entry.blank? || evidence_source.blank?
    return if reflection_entry.user_id == evidence_source.student_id

    errors.add(:evidence_source, "harus merupakan bukti milik mahasiswa yang menulis refleksi")
  end
end
