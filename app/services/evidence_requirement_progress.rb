# frozen_string_literal: true

# Computes expected-evidence progress from actual records. A record's presence
# is not enough by itself: pass counts, assessor diversity, and case diversity
# can be required by the rule stored on the requirement.
class EvidenceRequirementProgress
  Result = Data.define(:status, :record_count, :pass_count, :assessor_count, :case_count, :opportunity_count,
    :distinct_date_count, :span_days, :required_count, :requirement_version, :eligible_record_ids)

  def initialize(requirement, student: nil, evidence_date_range: nil, requirement_version: nil)
    @requirement = requirement
    @student = student
    @evidence_date_range = evidence_date_range
    @requirement_version = requirement_version
  end

  def call
    records = @requirement.evidence_records.includes(:assessment_instance, :activity_log, :reflection_entry,
      :epa_observation, :mini_cex_evaluation, :dops_evaluation, :wpba_observation, :evidence_source, :evidence_requirement_version).to_a
    records.select! { |record| record.student&.id == @student.id } if @student
    records.select! { |record| @evidence_date_range.cover?(record.evidence_date) } if @evidence_date_range
    version = @requirement_version || requirement_version_for(records)
    rule = version&.fulfillment_rule || @requirement.fulfillment_rule || {}
    source_type = version&.source_type || @requirement.source_type
    records.select! { |record| record.evidence_requirement_version_id == version.id } if version
    valid_results = rule.fetch("valid_results", EvidenceRecord::RESULTS - ["not_assessed"])
    latest_records = records.group_by(&:source_key).values.map do |versions|
      # Revision identifiers are opaque (an upstream may use a UUID or a
      # non-sortable sequence). Import order is the only safe chronology.
      versions.max_by { |record| [record.evidence_source&.created_at || record.created_at, record.id] }
    end
    eligible_records = latest_records.select { |record| valid_record?(record, rule, valid_results, source_type) }
    eligible_records.reject! { |record| source_key_reserved_by_sibling?(record, rule, valid_results, version) }
    pass_count = eligible_records.count { |record| record.result == "pass" }
    assessors = eligible_records.filter_map { |record| assessor_id(record) }.uniq
    cases = eligible_records.filter_map { |record| case_id(record) }.uniq
    opportunities = eligible_records.map { |record| source_key(record) }.uniq
    evidence_dates = eligible_records.map(&:evidence_date).compact.uniq.sort
    span_days = evidence_dates.size > 1 ? (evidence_dates.last - evidence_dates.first).to_i : 0
    required = [
      version&.required_count || @requirement.required_count,
      rule.fetch("minimum_valid_evidence", 0).to_i,
      rule.fetch("minimum_attempts", 0).to_i
    ].max
    met = eligible_records.size >= required &&
          pass_count >= rule.fetch("minimum_pass", 0).to_i &&
          cases.size >= rule.fetch("minimum_distinct_cases", 0).to_i &&
          assessors.size >= rule.fetch("minimum_assessors", 0).to_i &&
          assessors.size >= rule.fetch("minimum_distinct_assessors", 0).to_i &&
          opportunities.size >= rule.fetch("minimum_distinct_opportunities", 0).to_i &&
          evidence_dates.size >= rule.fetch("minimum_distinct_dates", 0).to_i &&
          span_days >= rule.fetch("minimum_span_days", 0).to_i &&
          (!rule["require_distinct_cases"] || cases.size >= required)

    Result.new(status: met ? :fulfilled : (records.empty? ? :not_started : :in_progress),
               record_count: eligible_records.size, pass_count: pass_count, assessor_count: assessors.size,
               case_count: cases.size, opportunity_count: opportunities.size,
               distinct_date_count: evidence_dates.size, span_days: span_days, required_count: required,
               requirement_version: version, eligible_record_ids: eligible_records.map(&:id))
  end

  private

  def requirement_version_for(records)
    versions = records.filter_map(&:evidence_requirement_version)
    return versions.min_by(&:version) if @student && versions.any?

    @requirement.current_version || versions.max_by(&:version)
  end

  def valid_record?(record, rule, valid_results, source_type)
    return false unless EvidenceRecord::RESULTS.include?(record.result)
    return false if rule.fetch("require_validation", true) && record.result == "not_assessed"
    return false unless valid_results.include?(record.result)
    return false if rule.fetch("require_validation", true) && record.evidence_source&.validation_status != "validated"
    return false unless source_type_matches?(record, source_type)

    true
  end

  def source_type_matches?(record, source_type)
    case source_type
    when "assessment" then record.assessment_instance.present? || record.evidence_source&.source_type == "assessment"
    when "logbook" then record.activity_log.present? || record.evidence_source&.source_type == "logbook"
    when "reflection" then record.reflection_entry.present? || record.evidence_source&.source_type == "reflection"
    when "wpba" then record.mini_cex_evaluation&.submitted? || record.dops_evaluation&.submitted? || record.wpba_observation&.submitted? ||
      record.evidence_source&.source_type == "wpba" ||
      record.evidence_source&.instrument_code.in?(%w[CBD MINI-CEX DOPS EPA-OBS])
    when "external" then record.evidence_source&.source_type == "external"
    when "epa_observation" then record.epa_observation&.status == "recorded" &&
      (!record.epa_observation.safety_flag? || record.epa_observation.safety_resolved_at.present?)
    when "portfolio", "other" then true
    else false
    end
  end

  def source_key(record)
    record.source_key
  end

  def source_key_reserved_by_sibling?(record, rule, valid_results, version)
    group = rule["independence_group"].to_s
    indicator_id = version&.indicator_id || @requirement.competency_indicator_id
    epa_id = version&.epa_id || @requirement.epa_id
    return false if group.blank? || (indicator_id.blank? && epa_id.blank?)

    sibling_scope = if indicator_id.present?
      EvidenceRequirement.where(competency_indicator_id: indicator_id)
    else
      EvidenceRequirement.where(epa_id: epa_id)
    end
    claimed_records = EvidenceRecord.where(evidence_requirement_id: sibling_scope)
      .where.not(evidence_requirement_id: @requirement.id)
      .where("evidence_records.evidence_requirement_id < ?", @requirement.id)
      .includes(:evidence_requirement_version, :assessment_instance, :activity_log, :reflection_entry,
        :epa_observation, :mini_cex_evaluation, :dops_evaluation, :wpba_observation, :evidence_source).to_a
    claimed_records.select! { |claimed_record| claimed_record.student&.id == record.student&.id }
    claimed_records.any? do |claimed_record|
        claimed_version = claimed_record.evidence_requirement_version
        claimed_rule = claimed_version&.fulfillment_rule || claimed_record.evidence_requirement.fulfillment_rule || {}
        claimed_valid_results = claimed_rule.fetch("valid_results", EvidenceRecord::RESULTS - ["not_assessed"])
        claimed_source_type = claimed_version&.source_type || claimed_record.evidence_requirement.source_type
        claimed_rule["independence_group"].to_s == group &&
          valid_record?(claimed_record, claimed_rule, claimed_valid_results, claimed_source_type) &&
          source_key(claimed_record) == source_key(record)
      end
  end

  def assessor_id(record)
    record.assessment_instance&.examiner_id || record.activity_log&.verified_by_id ||
      record.reflection_entry&.activity_log&.verified_by_id || record.epa_observation&.observer_id ||
      record.mini_cex_evaluation&.evaluator_id || record.dops_evaluation&.evaluator_id ||
      record.wpba_observation&.observer_id || record.evidence_source&.assessor_id
  end

  def case_id(record)
    record.assessment_instance&.clinical_case_id || record.reflection_entry&.clinical_case_id ||
      record.activity_log&.patient_code || record.epa_observation&.clinical_case_id ||
      record.mini_cex_evaluation&.clinical_case_id || record.dops_evaluation&.clinical_case_id ||
      record.wpba_observation&.clinical_case_id || record.evidence_source&.context&.fetch("case_id", nil)
  end
end
