# frozen_string_literal: true

class CompetencyAttainmentSnapshot
  def self.capture(student:, competency_item:)
    framework = competency_item.competency_framework
    raise ArgumentError, "Kompetensi tidak termasuk framework mahasiswa." unless
      framework.study_program_id == student.study_program_id

    requirements = EvidenceRequirement.where(competency_item_id: competency_item.id)
      .or(EvidenceRequirement.where(competency_indicator_id: competency_item.competency_indicators.select(:id)))
      .where(status: "active").includes(evidence_records: :evidence_source)

    {
      "framework_id" => framework.id,
      "framework_version" => framework.version,
      "competency_item_id" => competency_item.id,
      "captured_at" => Time.current.utc.iso8601(6),
      "requirements" => requirements.map do |requirement|
        progress = EvidenceRequirementProgress.new(requirement, student: student).call
        version = progress.requirement_version
        eligible_ids = progress.eligible_record_ids
        {
          "requirement_id" => requirement.id,
          "requirement_version_id" => version&.id,
          "requirement_version" => version&.version,
          "source_type" => version&.source_type || requirement.source_type,
          "rule" => version&.fulfillment_rule || requirement.fulfillment_rule,
          "status" => progress.status.to_s,
          "record_count" => progress.record_count,
          "sources" => requirement.evidence_records.includes(:assessment_instance, :activity_log, :reflection_entry,
            :epa_observation, :mini_cex_evaluation, :dops_evaluation, :evidence_source)
            .select { |record| eligible_ids.include?(record.id) }.map do |record|
            {
              "evidence_record_id" => record.id,
              "source_key" => record.source_key,
              "date" => record.evidence_date&.iso8601,
              "result" => record.result,
              "validation_status" => record.evidence_source&.validation_status
            }
          end
        }
      end
    }
  end

  def self.capture_epa_dossier(student:, epa:)
    framework = epa.competency_framework
    raise ArgumentError, "EPA tidak termasuk framework mahasiswa." unless framework.study_program_id == student.study_program_id

    requirements = EvidenceRequirement.where(epa: epa, status: "active").includes(:evidence_records)
    {
      "student_id" => student.id,
      "epa_id" => epa.id,
      "epa_code" => epa.code,
      "epa_title" => epa.title,
      "framework_id" => framework.id,
      "framework_version" => framework.version,
      "captured_at" => Time.current.utc.iso8601(6),
      "competencies" => epa.epa_competencies.includes(:competency_item).map do |mapping|
        { "competency_item_id" => mapping.competency_item_id,
          "code" => mapping.competency_item.code, "title" => mapping.competency_item.title,
          "ksa_dimension" => mapping.ksa_dimension, "critical" => mapping.critical }
      end,
      "requirements" => requirements.map do |requirement|
        progress = EvidenceRequirementProgress.new(requirement, student: student).call
        { "requirement_id" => requirement.id,
          "requirement_version_id" => progress.requirement_version&.id,
          "status" => progress.status.to_s,
          "record_count" => progress.record_count,
          "source_keys" => requirement.evidence_records.select do |record|
            progress.eligible_record_ids.include?(record.id)
          end.map(&:source_key).uniq }
      end,
      "observations" => epa.epa_observations.where(student: student, status: "recorded")
        .order(:observed_at).map do |observation|
          { "id" => observation.id, "observer_id" => observation.observer_id,
            "observed_at" => observation.observed_at&.iso8601,
            "supervision_level_id" => observation.supervision_level_id,
            "case_complexity" => observation.complexity,
            "safety_flag" => observation.safety_flag }
        end
    }
  end
end
