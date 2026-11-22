# frozen_string_literal: true

class ArtifactSubmission < ApplicationRecord
  SOURCE_MODELS = {
    "ActivityLog" => ActivityLog,
    "ReflectionEntry" => ReflectionEntry,
    "EvidenceRecord" => EvidenceRecord
  }.freeze
  STATUSES = %w[submitted approved rejected withdrawn].freeze

  belongs_to :student, class_name: "User"
  belongs_to :reviewer, class_name: "User", optional: true
  has_one :portfolio_selection, dependent: :destroy
  has_many :reviews, class_name: "ArtifactSubmissionReview", dependent: :restrict_with_error

  validates :source_type, inclusion: { in: SOURCE_MODELS.keys }
  validates :source_id, :selection_reason, :submitted_at, presence: true
  validates :selection_reason, length: { minimum: 10, maximum: 2000 }
  validates :reflection, length: { maximum: 5000 }, allow_nil: true
  validates :status, inclusion: { in: STATUSES }
  validates :source_id, uniqueness: { scope: %i[student_id source_type] }
  validate :source_belongs_to_student, on: :create
  validate :review_state_is_consistent
  validate :source_provenance_is_immutable
  before_validation :capture_source_provenance, on: :create

  scope :awaiting_review, -> { where(status: "submitted").order(submitted_at: :asc) }

  def source_record
    SOURCE_MODELS[source_type]&.find_by(id: source_id)
  end

  def source_title
    return source_provenance["label"] if source_provenance["label"].present?

    record = source_record
    case record
    when ActivityLog then record.title
    when ReflectionEntry then record.title.presence || "Refleksi #{record.entry_date}"
    when EvidenceRecord
      label = EvidenceRequirement::SOURCE_TYPE_LABELS.fetch(record.evidence_requirement.source_type, "Bukti")
      "#{label} · #{record.evidence_date}"
    else source_provenance.fetch("label", "Artefak tidak tersedia")
    end
  end

  def clinical_rotation
    record = source_record
    return record.clinical_rotation if record.respond_to?(:clinical_rotation)
    return record.activity_log&.clinical_rotation if record.is_a?(EvidenceRecord)

    nil
  end

  def review!(by:, decision:, notes:)
    raise ArgumentError, "Keputusan telaah tidak dikenal." unless %w[approved rejected].include?(decision)
    raise ArgumentError, "Catatan telaah minimal 10 karakter." if notes.to_s.strip.length < 10
    raise ArgumentError, "Pengajuan tidak lagi menunggu telaah." unless submitted?

    self.class.transaction do
      reviews.create!(reviewer: by, decision: decision, notes: notes.to_s.strip, reviewed_at: Time.current)
      update!(status: decision, reviewer: by, reviewed_at: Time.current, review_notes: notes.to_s.strip)
    end
  end

  def resubmit!
    raise ArgumentError, "Hanya pengajuan yang ditolak dapat diajukan ulang." unless status == "rejected"

    update!(status: "submitted", reviewer: nil, reviewed_at: nil, review_notes: nil, submitted_at: Time.current)
  end

  def submitted? = status == "submitted"
  def approved? = status == "approved"

  private

  def source_belongs_to_student
    record = source_record
    errors.add(:source_id, "bukan bukti milik mahasiswa ini") if record.blank? || source_owner_id(record) != student_id
    return if record.blank? || source_owner_id(record) != student_id

    if record.is_a?(ActivityLog) && !record.verified?
      errors.add(:source_id, "kegiatan harus divalidasi sebelum diajukan sebagai artefak")
    elsif record.is_a?(EvidenceRecord) && record.evidence_source&.validation_status != "validated"
      errors.add(:source_id, "bukti harus divalidasi sebelum diajukan sebagai artefak")
    end
  end

  def capture_source_provenance
    record = source_record
    return if record.blank?

    label = case record
    when ActivityLog then record.title
    when ReflectionEntry then record.title.presence || "Refleksi #{record.entry_date}"
    when EvidenceRecord
      EvidenceRequirement::SOURCE_TYPE_LABELS.fetch(record.evidence_requirement.source_type, "Bukti") + " · #{record.evidence_date}"
    end
    occurred_on = case record
    when ActivityLog then record.activity_date
    when ReflectionEntry then record.entry_date
    when EvidenceRecord then record.evidence_date
    end
    self.source_provenance = {
      "source_type" => source_type,
      "source_id" => source_id,
      "source_version_at" => record.updated_at&.utc&.iso8601(6),
      "captured_at" => Time.current.utc.iso8601(6),
      "provenance_quality" => "source_version_at_submission",
      "occurred_on" => occurred_on&.iso8601,
      "label" => label
    }
  end

  def source_provenance_is_immutable
    return unless persisted?
    return unless will_save_change_to_attribute?(:source_type) || will_save_change_to_attribute?(:source_id) ||
      will_save_change_to_attribute?(:source_provenance)

    errors.add(:source_provenance, "referensi dan versi sumber artefak tidak dapat diubah")
  end

  def source_owner_id(record)
    record.is_a?(EvidenceRecord) ? record.student&.id : record.user_id
  end

  def review_state_is_consistent
    if status.in?(%w[approved rejected]) && (reviewer_id.blank? || reviewed_at.blank? || review_notes.blank?)
      errors.add(:reviewer, "keputusan telaah harus mencatat penelaah, waktu, dan catatan")
    end
    errors.add(:base, "artefak yang sudah ditelaah tidak dapat ditarik") if status == "withdrawn" && reviewed_at.present?
  end
end
