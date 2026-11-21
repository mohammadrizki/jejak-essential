# frozen_string_literal: true

class EvidenceRecord < ApplicationRecord
  RESULTS = %w[pass fail borderline not_assessed other].freeze
  belongs_to :evidence_requirement
  belongs_to :assessment_instance, optional: true
  belongs_to :activity_log, optional: true
  belongs_to :reflection_entry, optional: true
  belongs_to :epa_observation, optional: true
  belongs_to :mini_cex_evaluation, optional: true
  belongs_to :dops_evaluation, optional: true
  belongs_to :evidence_source, optional: true

  validates :evidence_date, presence: true
  validates :result, inclusion: { in: RESULTS }
  validates :assessment_instance_id, uniqueness: { scope: :evidence_requirement_id }, if: -> { assessment_instance_id.present? }
  validates :activity_log_id, uniqueness: { scope: :evidence_requirement_id }, if: -> { activity_log_id.present? }
  validates :reflection_entry_id, uniqueness: { scope: :evidence_requirement_id }, if: -> { reflection_entry_id.present? }
  validates :epa_observation_id, uniqueness: { scope: :evidence_requirement_id }, if: -> { epa_observation_id.present? }
  validates :mini_cex_evaluation_id, uniqueness: { scope: :evidence_requirement_id }, if: -> { mini_cex_evaluation_id.present? }
  validates :dops_evaluation_id, uniqueness: { scope: :evidence_requirement_id }, if: -> { dops_evaluation_id.present? }

  validate :exactly_one_source
  validate :assessment_source_matches_blueprint_item
  validate :source_matches_requirement
  before_validation :assign_canonical_evidence_source

  def student
    assessment_instance&.student || activity_log&.user || reflection_entry&.user || epa_observation&.student ||
      mini_cex_evaluation&.student || dops_evaluation&.student || evidence_source&.student
  end

  def source_key
    return ["canonical", evidence_source.source_system, evidence_source.activity_key] if evidence_source
    return ["assessment", assessment_instance_id] if assessment_instance_id
    return ["logbook", activity_log_id] if activity_log_id
    return ["reflection", reflection_entry_id] if reflection_entry_id
    return ["epa_observation", epa_observation_id] if epa_observation_id
    return ["mini_cex", mini_cex_evaluation_id] if mini_cex_evaluation_id
    return ["dops", dops_evaluation_id] if dops_evaluation_id

    nil
  end

  private

  def exactly_one_source
    sources = [assessment_instance, activity_log, reflection_entry, epa_observation,
               mini_cex_evaluation, dops_evaluation].count(&:present?)
    valid = (sources == 1 && evidence_source.present?) || (sources.zero? && evidence_source.present?)
    errors.add(:base, "tepat satu sumber bukti aktual harus dipilih") unless valid
  end

  def assessment_source_matches_blueprint_item
    return unless assessment_instance && evidence_requirement&.origin == "blueprint"
    return if assessment_instance.assessment_event.blueprint_item_id == evidence_requirement.blueprint_item_id

    errors.add(:assessment_instance, "event asesmen belum ditautkan ke komponen blueprint yang diwajibkan")
  end

  def source_matches_requirement
    requirement = evidence_requirement
    return if requirement.blank?
    return if requirement.source_type.in?(%w[portfolio other])
    return if requirement.source_type == "assessment" && assessment_instance.present?
    return if requirement.source_type == "logbook" && activity_log.present?
    return if requirement.source_type == "reflection" && reflection_entry.present?
    return if requirement.source_type == "epa_observation" && epa_observation.present?
    return if requirement.source_type == "wpba" && (mini_cex_evaluation.present? || dops_evaluation.present?)
    return if requirement.source_type == "external" && evidence_source&.source_type == "external"

    errors.add(:base, "sumber bukti tidak sesuai dengan jenis yang disyaratkan")
  end

  def assign_canonical_evidence_source
    return if evidence_source.present?

    source = assessment_instance || activity_log || reflection_entry || epa_observation ||
      mini_cex_evaluation || dops_evaluation
    return if source.blank?

    self.evidence_source = EvidenceSource.for_local_record!(source)
  end
end
