# frozen_string_literal: true

class EvidenceRecord < ApplicationRecord
  RESULTS = %w[pass fail borderline not_assessed other].freeze
  belongs_to :evidence_requirement
  belongs_to :assessment_instance, optional: true
  belongs_to :activity_log, optional: true
  belongs_to :reflection_entry, optional: true
  belongs_to :epa_observation, optional: true

  validates :evidence_date, presence: true
  validates :result, inclusion: { in: RESULTS }
  validates :assessment_instance_id, uniqueness: { scope: :evidence_requirement_id }, if: -> { assessment_instance_id.present? }
  validates :activity_log_id, uniqueness: { scope: :evidence_requirement_id }, if: -> { activity_log_id.present? }
  validates :reflection_entry_id, uniqueness: { scope: :evidence_requirement_id }, if: -> { reflection_entry_id.present? }
  validates :epa_observation_id, uniqueness: { scope: :evidence_requirement_id }, if: -> { epa_observation_id.present? }

  validate :exactly_one_source
  validate :assessment_source_matches_blueprint_item
  validate :source_matches_requirement

  def student
    assessment_instance&.student || activity_log&.user || reflection_entry&.user || epa_observation&.student
  end

  private

  def exactly_one_source
    sources = [assessment_instance, activity_log, reflection_entry, epa_observation].count(&:present?)
    errors.add(:base, "tepat satu sumber bukti aktual harus dipilih") unless sources == 1
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

    errors.add(:base, "sumber bukti tidak sesuai dengan jenis yang disyaratkan")
  end
end
