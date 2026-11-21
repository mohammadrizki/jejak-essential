# frozen_string_literal: true

class BlueprintItemEpa < ApplicationRecord
  PURPOSES = %w[formative summative entrustment].freeze
  belongs_to :blueprint_item
  belongs_to :epa
  belongs_to :supervision_level, optional: true

  validates :assessment_purpose, inclusion: { in: PURPOSES },
                                uniqueness: { scope: %i[blueprint_item_id epa_id] }
  validates :expected_level, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :framework_matches
  validate :blueprint_version_is_draft
  validate :target_scale_matches

  private

  def framework_matches
    return if blueprint_item.blank? || epa.blank?
    return if blueprint_item.blueprint_version.competency_framework_id == epa.competency_framework_id

    errors.add(:epa, "harus berasal dari framework versi blueprint")
  end

  def blueprint_version_is_draft
    return if blueprint_item&.blueprint_version&.status == "draft"
    return if persisted? && !changed?

    errors.add(:base, "Pemetaan EPA komponen terbit hanya dapat diubah melalui versi draf")
  end

  def target_scale_matches
    return if supervision_level.blank?
    return if assessment_purpose == "entrustment" &&
              supervision_level.supervision_scale_version.use_case == "prospective_entrustment" &&
              (expected_level.blank? || expected_level == supervision_level.ordinal)

    errors.add(:supervision_level, "hanya dipakai untuk tujuan entrustment dengan level prospektif yang cocok")
  end
end
