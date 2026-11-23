# frozen_string_literal: true

# Idempotent bridge entry point for approved external adapters. Imported data
# remains unverified until a JEJAK reviewer validates its provenance/result.
class CanonicalEvidenceIngestor
  RESERVED_METADATA_KEYS = %w[jejak_import_batch_id jejak_imported_by_id].freeze

  def initialize(source_system:, payload:, requirement:, batch: nil, actor: nil)
    @source_system = source_system.to_s
    @payload = payload.to_h.deep_stringify_keys
    @requirement = requirement
    @batch = batch
    @actor = actor
  end

  def call
    validate_payload!
    EvidenceSource.transaction do
      source = find_or_create_source!
      @requirement.evidence_records.find_or_create_by!(evidence_source: source) do |record|
        record.evidence_date = source.occurred_on
        record.result = "not_assessed"
        record.metadata = { "ingested_by_adapter" => @source_system }
      end
    end
  end

  private

  def find_or_create_source!
    identity = { source_system: @source_system, source_record_id: @payload.fetch("source_record_id"),
      source_revision: @payload.fetch("source_revision") }
    existing = EvidenceSource.find_by(identity)
    return verify_unchanged_revision!(existing) if existing

    EvidenceSource.create!(
      identity.merge(
        student: @payload.fetch("student"),
        source_type: "external",
        activity_key: @payload.fetch("activity_key"),
        occurred_on: Date.iso8601(@payload.fetch("occurred_on").to_s),
        validation_status: "unverified",
        instrument_code: @payload["instrument_code"],
        instrument_version: @payload["instrument_version"],
        score: @payload["score"],
        result: @payload["result"],
        feedback: @payload["feedback"],
        context: @payload.fetch("context", {}),
        metadata: external_metadata.merge(import_provenance)
      )
    )
  end

  def verify_unchanged_revision!(source)
    expected_payload = {
      student_id: @payload.fetch("student").id,
      activity_key: @payload.fetch("activity_key"),
      occurred_on: Date.iso8601(@payload.fetch("occurred_on").to_s),
      instrument_code: @payload["instrument_code"], instrument_version: @payload["instrument_version"],
      score: @payload["score"], result: @payload["result"], feedback: @payload["feedback"],
      context: @payload.fetch("context", {}), metadata: external_metadata
    }
    existing_metadata = source.metadata.to_h.except(*RESERVED_METADATA_KEYS)
    return source if expected_payload.all? do |attribute, value|
      attribute == :metadata ? existing_metadata == value : source.public_send(attribute) == value
    end

    raise ArgumentError, "Identifier sumber dan revisi yang sama datang dengan payload yang berbeda."
  end

  def external_metadata
    @external_metadata ||= @payload.fetch("metadata", {}).to_h.deep_stringify_keys.except(*RESERVED_METADATA_KEYS)
  end

  def import_provenance
    return {} unless @batch || @actor

    { "jejak_import_batch_id" => @batch&.id, "jejak_imported_by_id" => @actor&.id }.compact
  end

  def validate_payload!
    raise ArgumentError, "Sistem sumber wajib diisi." if @source_system.blank?
    %w[source_record_id source_revision activity_key occurred_on].each do |key|
      raise ArgumentError, "#{key} wajib diisi." if @payload[key].blank?
    end
    raise ArgumentError, "Jenis Bukti yang Diharapkan harus eksternal." unless @requirement.source_type == "external"
    student = @payload["student"]
    raise ArgumentError, "Mahasiswa wajib berupa akun JEJAK." unless student.is_a?(User)
    framework = @requirement.competency_item&.competency_framework ||
      @requirement.epa&.competency_framework ||
      @requirement.blueprint_item&.blueprint_version&.competency_framework
    raise ArgumentError, "Bukti harus sesuai program studi pemilik syarat." unless framework&.study_program_id == student.study_program_id
    if @requirement.epa.present?
      configuration = ModuleConfiguration.for(framework.study_program)
      raise ArgumentError, "Observasi EPA eksternal harus berasal dari WPBA klinis." unless @source_system == "clinical_wpba"
      raise ArgumentError, "EPA atau adapter WPBA klinis eksternal belum diaktifkan." unless
        configuration.enabled?("epa") && configuration.enabled?("integration_clinical_wpba")
    end
  end
end
