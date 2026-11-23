# frozen_string_literal: true

# Stable source activity shared by one or more requirement-specific evidence
# links. Revisions have separate rows but retain activity_key, so a correction
# never creates a second independent opportunity.
class EvidenceSource < ApplicationRecord
  SOURCE_TYPES = %w[assessment wpba logbook reflection epa_observation external].freeze
  VALIDATION_STATUSES = %w[unverified validated rejected].freeze
  RESULTS = %w[pass fail borderline not_assessed other].freeze

  belongs_to :student, class_name: "User"
  belongs_to :assessor, class_name: "User", optional: true
  belongs_to :validated_by, class_name: "User", optional: true
  has_many :evidence_records, dependent: :restrict_with_error

  validates :source_system, :source_type, :source_record_id, :source_revision,
    :activity_key, :occurred_on, presence: true
  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :validation_status, inclusion: { in: VALIDATION_STATUSES }
  validates :result, inclusion: { in: RESULTS }, allow_nil: true
  validates :source_record_id, uniqueness: { scope: %i[source_system source_revision] }
  validates :activity_key, length: { maximum: 255 }
  validate :validation_metadata_is_consistent
  validate :external_source_review_transition
  validate :external_source_payload_is_immutable

  def self.for_local_record!(record)
    source_type = case record
    when AssessmentInstance then "assessment"
    when ActivityLog then "logbook"
    when ReflectionEntry then "reflection"
    when EpaObservation then "epa_observation"
    when MiniCexEvaluation, DopsEvaluation, WpbaObservation then "wpba"
    end
    raise ArgumentError, "Jenis sumber bukti lokal tidak dikenali." if source_type.blank?

    revision = record.updated_at&.utc&.iso8601(6) || record.created_at&.utc&.iso8601(6) || "initial"
    attrs = local_attributes(record, source_type, revision)
    find_or_create_by!(source_system: "jejak", source_record_id: record.id.to_s, source_revision: revision) do |source|
      source.assign_attributes(attrs)
    end
  end

  def self.local_attributes(record, source_type, revision)
    student = case record
    when ActivityLog then record.user
    when ReflectionEntry then record.user
    else record.student
    end
    occurred_on = case record
    when AssessmentInstance then record.effective_date
    when ActivityLog then record.activity_date
    when ReflectionEntry then record.entry_date
    when EpaObservation then record.observed_at.to_date
    when WpbaObservation then record.observed_at.to_date
    else record.evaluated_at
    end
    assessor = case record
    when AssessmentInstance then record.examiner
    when ActivityLog then record.verified_by
    when EpaObservation then record.observer
    when MiniCexEvaluation, DopsEvaluation then record.evaluator
    when WpbaObservation then record.observer
    end
    result = case record
    when ActivityLog then record.verified_at.present? ? "pass" : "not_assessed"
    when AssessmentInstance then record.status == "scored" ? "other" : "not_assessed"
    when ReflectionEntry then "other"
    else "other"
    end
    validated = case record
    when ActivityLog then record.verified_at.present?
    when AssessmentInstance then record.status == "scored" && record.examiner.present?
    when ReflectionEntry then false
    when EpaObservation then record.status == "recorded" && (!record.safety_flag? || record.safety_resolved_at.present?)
    when MiniCexEvaluation, DopsEvaluation, WpbaObservation then record.submitted?
    end
    instrument_version = case record
    when AssessmentInstance then record.assessment_event&.wpba_instrument_version
    when MiniCexEvaluation, DopsEvaluation then record.wpba_instrument_version
    when WpbaObservation then record.wpba_instrument_version
    end
    context = case record
    when ActivityLog
      { "rotation_id" => record.clinical_rotation_id, "domain_id" => record.academic_activity_domain_id }
    when AssessmentInstance
      { "assessment_event_id" => record.assessment_event_id, "case_id" => record.clinical_case_id }
    when ReflectionEntry
      { "activity_log_id" => record.activity_log_id, "case_id" => record.clinical_case_id }
    when EpaObservation
      { "rotation_id" => record.clinical_rotation_id, "case_id" => record.clinical_case_id,
        "complexity" => record.complexity, "supervision_level_id" => record.supervision_level_id,
        "safety_flag" => record.safety_flag?, "safety_resolved" => record.safety_resolved_at.present? }
    when MiniCexEvaluation, DopsEvaluation
      { "rotation_id" => record.clinical_rotation_id, "case_id" => record.clinical_case_id,
        "complexity" => record.case_complexity }
    when WpbaObservation
      record.clinical_context.to_h.merge("rotation_id" => record.clinical_rotation_id,
        "case_id" => record.clinical_case_id)
    else
      {}
    end
    {
      student: student, assessor: assessor, source_system: "jejak", source_type: source_type,
      source_record_id: record.id.to_s, source_revision: revision,
      activity_key: record.respond_to?(:source_activity_key) ? record.source_activity_key : "#{record.model_name.singular}:#{record.id}", occurred_on: occurred_on,
      validation_status: validated ? "validated" : "unverified",
      instrument_code: instrument_version&.wpba_instrument&.code ||
        (source_type == "wpba" ? record.class.name.underscore : source_type),
      instrument_version: instrument_version&.version_label ||
        (source_type == "wpba" ? "legacy-v1" : nil),
      score: record.respond_to?(:score) ? record.score : record.respond_to?(:average_score) ? record.average_score : nil,
      result: result, feedback: record.respond_to?(:overall_feedback) ? record.overall_feedback : nil,
      context: context.compact, metadata: { "source_revision" => revision },
      validated_at: validated ? (record.respond_to?(:verified_at) ? record.verified_at : record.respond_to?(:scored_at) ? record.scored_at : record.updated_at) : nil,
      validated_by: validated ? assessor : nil
    }
  end

  def validate_source!(by:)
    self.class.transaction do
      ensure_external_source_pending!
      update!(validation_status: "validated", validated_by: by, validated_at: Time.current)
      evidence_records.find_each do |record|
        record.update!(result: result.presence || "other", score: score, feedback: feedback)
      end
    end
  end

  def reject_source!(by:, reason:)
    raise ArgumentError, "Alasan penolakan wajib diisi." if reason.to_s.strip.length < 10
    ensure_external_source_pending!

    update!(validation_status: "rejected", validated_by: by, validated_at: Time.current,
      metadata: metadata.merge("rejection_reason" => reason.to_s.strip))
  end

  private

  def ensure_external_source_pending!
    raise ArgumentError, "Hanya bukti eksternal yang menunggu validasi dapat ditinjau." unless
      source_type == "external" && validation_status == "unverified"
  end

  def validation_metadata_is_consistent
    return unless validation_status == "validated" || validation_status == "rejected"

    errors.add(:validated_at, "wajib dicatat") if validated_at.blank?
    errors.add(:validated_by, "wajib dicatat") if validated_by.blank?
  end

  def external_source_review_transition
    return unless persisted? && source_type == "external" && will_save_change_to_validation_status?

    previous = validation_status_in_database
    unless previous == "unverified" && validation_status.in?(%w[validated rejected])
      errors.add(:validation_status, "bukti eksternal hanya dapat ditinjau satu kali dari status menunggu")
    end
  end

  def external_source_payload_is_immutable
    return unless persisted? && source_type == "external"

    %w[student_id source_system source_record_id source_revision activity_key occurred_on instrument_code
      instrument_version score result feedback context].each do |attribute|
      if will_save_change_to_attribute?(attribute)
        errors.add(attribute, "payload sumber yang diimpor tidak dapat diubah setelah pencatatan")
      end
    end
    return unless will_save_change_to_metadata?

    before = metadata_in_database.to_h.except("rejection_reason")
    after = metadata.to_h.except("rejection_reason")
    errors.add(:metadata, "provenance sumber tidak dapat diubah") unless before == after
  end
end
