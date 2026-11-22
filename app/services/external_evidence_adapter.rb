# frozen_string_literal: true

class ExternalEvidenceAdapter
  ADAPTERS = {
    "MoodleAdapter" => "integration_moodle",
    "ExamtoolAdapter" => "integration_examtool",
    "OsceAdapter" => "integration_osce",
    "ClinicalWpbaAdapter" => "integration_clinical_wpba"
  }.freeze

  def initialize(study_program:)
    @study_program = study_program
  end

  def ingest!(payload:, requirement:, batch: nil, actor: nil)
    ensure_enabled!
    if requirement.epa.present? && source_system != "clinical_wpba"
      raise ArgumentError, "Syarat Bukti EPA eksternal hanya dapat diisi melalui adapter WPBA klinis eksternal."
    end
    normalized = payload.to_h.deep_stringify_keys
    normalized["student"] ||= ExternalIdentityResolver.resolve_student!(
      source_system: source_system, external_id: normalized.delete("student_external_id")
    )
    raise ArgumentError, "Mahasiswa bukti berbeda dari program studi adapter." unless
      normalized["student"].study_program_id == @study_program.id

    CanonicalEvidenceIngestor.new(source_system: source_system, payload: normalized,
      requirement: requirement, batch: batch, actor: actor).call
  end

  private

  def ensure_enabled!
    key = ADAPTERS[self.class.name]
    raise ArgumentError, "Adapter #{source_system} belum diaktifkan untuk program studi ini." unless
      ModuleConfiguration.for(@study_program).enabled?(key)
  end

  def source_system
    raise NotImplementedError
  end
end
