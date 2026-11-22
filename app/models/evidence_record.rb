# frozen_string_literal: true

class EvidenceRecord < ApplicationRecord
  RESULTS = %w[pass fail borderline not_assessed other].freeze
  belongs_to :evidence_requirement
  belongs_to :evidence_requirement_version, optional: true
  belongs_to :assessment_instance, optional: true
  belongs_to :activity_log, optional: true
  belongs_to :reflection_entry, optional: true
  belongs_to :epa_observation, optional: true
  belongs_to :mini_cex_evaluation, optional: true
  belongs_to :dops_evaluation, optional: true
  belongs_to :wpba_observation, optional: true
  belongs_to :evidence_source, optional: true

  validates :evidence_date, presence: true
  validates :result, inclusion: { in: RESULTS }
  validates :assessment_instance_id, uniqueness: { scope: :evidence_requirement_id }, if: -> { assessment_instance_id.present? }
  validates :activity_log_id, uniqueness: { scope: :evidence_requirement_id }, if: -> { activity_log_id.present? }
  validates :reflection_entry_id, uniqueness: { scope: :evidence_requirement_id }, if: -> { reflection_entry_id.present? }
  validates :epa_observation_id, uniqueness: { scope: :evidence_requirement_id }, if: -> { epa_observation_id.present? }
  validates :mini_cex_evaluation_id, uniqueness: { scope: :evidence_requirement_id }, if: -> { mini_cex_evaluation_id.present? }
  validates :dops_evaluation_id, uniqueness: { scope: :evidence_requirement_id }, if: -> { dops_evaluation_id.present? }
  validates :wpba_observation_id, uniqueness: { scope: :evidence_requirement_id }, if: -> { wpba_observation_id.present? }

  validate :exactly_one_source
  validate :assessment_source_matches_blueprint_item
  validate :source_matches_requirement
  before_validation :assign_canonical_evidence_source
  before_validation :assign_requirement_version
  validate :requirement_version_matches_requirement
  before_destroy :prevent_deletion_when_selected_as_artifact

  def student
    assessment_instance&.student || activity_log&.user || reflection_entry&.user || epa_observation&.student ||
      mini_cex_evaluation&.student || dops_evaluation&.student || wpba_observation&.student || evidence_source&.student
  end

  def source_key
    return ["canonical", evidence_source.source_system, evidence_source.activity_key] if evidence_source
    return ["assessment", assessment_instance_id] if assessment_instance_id
    return ["logbook", activity_log_id] if activity_log_id
    return ["reflection", reflection_entry_id] if reflection_entry_id
    return ["epa_observation", epa_observation_id] if epa_observation_id
    return ["mini_cex", mini_cex_evaluation_id] if mini_cex_evaluation_id
    return ["dops", dops_evaluation_id] if dops_evaluation_id
    return ["wpba", wpba_observation.source_activity_key] if wpba_observation_id

    nil
  end

  private

  def prevent_deletion_when_selected_as_artifact
    return unless ArtifactSubmission.exists?(source_type: "EvidenceRecord", source_id: id)

    errors.add(:base, "Bukti yang menjadi sumber artefak tidak dapat dihapus; batalkan pengajuan artefak terlebih dahulu")
    throw :abort
  end

  def exactly_one_source
    sources = [assessment_instance, activity_log, reflection_entry, epa_observation,
               mini_cex_evaluation, dops_evaluation, wpba_observation].count(&:present?)
    valid = (sources == 1 && evidence_source.present?) || (sources.zero? && evidence_source.present?)
    errors.add(:base, "tepat satu sumber bukti aktual harus dipilih") unless valid
  end

  def assessment_source_matches_blueprint_item
    requirement = evidence_requirement
    return unless assessment_instance && requirement&.origin == "blueprint"
    expected_item_id = evidence_requirement_version&.configuration&.fetch("blueprint_item_id", nil) || requirement.blueprint_item_id
    return if expected_item_id.present? && assessment_instance.assessment_event.blueprint_item_id == expected_item_id

    errors.add(:assessment_instance, "event asesmen belum ditautkan ke komponen blueprint yang diwajibkan")
  end

  def source_matches_requirement
    requirement = evidence_requirement
    return if requirement.blank?
    source_type = evidence_requirement_version&.source_type || requirement.source_type
    return if source_type.in?(%w[portfolio other])
    return if source_type == "assessment" && assessment_instance.present?
    return if source_type == "logbook" && activity_log.present?
    return if source_type == "reflection" && reflection_entry.present?
    return if source_type == "epa_observation" && epa_observation.present?
    return if source_type == "wpba" &&
      (mini_cex_evaluation.present? || dops_evaluation.present? ||
        evidence_source&.instrument_code.in?(%w[CBD MINI-CEX DOPS EPA-OBS]) || wpba_observation.present?)
    return if source_type == "external" && evidence_source&.source_type == "external"

    errors.add(:base, "sumber bukti tidak sesuai dengan jenis yang disyaratkan")
  end

  def assign_canonical_evidence_source
    return if evidence_source.present?

    source = assessment_instance || activity_log || reflection_entry || epa_observation ||
      mini_cex_evaluation || dops_evaluation || wpba_observation
    return if source.blank?

    self.evidence_source = EvidenceSource.for_local_record!(source)
  end

  def assign_requirement_version
    return if evidence_requirement_version.present? || evidence_requirement.blank?

    same_student_record = evidence_requirement.evidence_records
      .where.not(id: id)
      .includes(:evidence_requirement_version, :assessment_instance, :activity_log, :reflection_entry,
        :epa_observation, :mini_cex_evaluation, :dops_evaluation, :wpba_observation, :evidence_source)
      .detect { |record| record.student&.id == student&.id && record.evidence_requirement_version.present? }

    self.evidence_requirement_version = same_student_record&.evidence_requirement_version ||
      evidence_requirement.current_version
  end

  def requirement_version_matches_requirement
    return if evidence_requirement_version.blank? || evidence_requirement.blank?
    return if evidence_requirement_version.evidence_requirement_id == evidence_requirement_id

    errors.add(:evidence_requirement_version, "harus berasal dari Syarat Bukti yang sama")
  end
end
