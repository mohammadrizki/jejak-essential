# frozen_string_literal: true

# Jurnal reflektif tersendiri — beda dari field `reflection` ringkas di
# ActivityLog/ClinicalCase, ini untuk tulisan reflektif yang lebih bebas,
# bisa berdiri sendiri atau ditautkan ke kegiatan/kasus tertentu.
class ReflectionEntry < ApplicationRecord
  belongs_to :user
  belongs_to :activity_log, optional: true
  belongs_to :clinical_case, optional: true
  has_many :reflection_entry_competency_tags, dependent: :destroy
  has_many :competency_items, through: :reflection_entry_competency_tags
  has_many :reflection_entry_evidence_sources, dependent: :destroy
  has_many :evidence_sources, through: :reflection_entry_evidence_sources

  validates :entry_date, presence: true
  validate :content_or_structured_reflection
  validate :linked_records_belong_to_owner
  validate :competencies_belong_to_program
  validate :evidence_sources_belong_to_owner
  before_validation :compose_content_from_prompts
  before_destroy :prevent_deletion_when_selected_as_artifact

  scope :recent, -> { order(entry_date: :desc, created_at: :desc) }

  private

  def prevent_deletion_when_selected_as_artifact
    return unless ArtifactSubmission.exists?(source_type: "ReflectionEntry", source_id: id)

    errors.add(:base, "Refleksi yang menjadi sumber artefak tidak dapat dihapus; batalkan pengajuan artefak terlebih dahulu")
    throw :abort
  end

  # Id kiriman form bisa diubah: tanpa ini refleksi dapat menaut (dan
  # menampilkan judul) kegiatan/kasus milik mahasiswa lain.
  def linked_records_belong_to_owner
    errors.add(:activity_log, "bukan kegiatan milik Anda") if activity_log && activity_log.user_id != user_id
    errors.add(:clinical_case, "bukan kasus milik Anda") if clinical_case && clinical_case.user_id != user_id
  end

  def content_or_structured_reflection
    errors.add(:content, "isi setidaknya satu bagian refleksi") if
      content.blank? && [what_happened, what_learned, what_to_improve, next_action].all?(&:blank?)
  end

  def compose_content_from_prompts
    return if [what_happened, what_learned, what_to_improve, next_action].all?(&:blank?)

    self.content = {
      "Apa yang saya alami?" => what_happened,
      "Apa yang saya pelajari?" => what_learned,
      "Apa yang masih perlu saya perbaiki?" => what_to_improve,
      "Apa yang akan saya lakukan selanjutnya?" => next_action
    }.filter_map { |prompt, answer| "#{prompt}\n#{answer}" if answer.present? }.join("\n\n")
  end

  def competencies_belong_to_program
    allowed_ids = user&.study_program&.peta_kompetensi&.competency_items&.select(:id)
    return if competency_item_ids.blank?
    return if allowed_ids.present? && competency_item_ids.all? { |id| allowed_ids.where(id: id).exists? }

    errors.add(:competency_items, "harus berasal dari Peta Kompetensi program studi Anda")
  end

  def evidence_sources_belong_to_owner
    return if evidence_sources.all? { |source| source.student_id == user_id }

    errors.add(:evidence_sources, "hanya boleh berasal dari Koleksi Bukti milik Anda")
  end
end
