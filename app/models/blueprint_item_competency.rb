# frozen_string_literal: true

class BlueprintItemCompetency < ApplicationRecord
  belongs_to :blueprint_item
  belongs_to :competency_item
  belongs_to :competency_indicator, optional: true

  validates :competency_item_id, uniqueness: { scope: %i[blueprint_item_id competency_indicator_id] }
  validate :targets_are_in_same_framework
  validate :indicator_matches_competency
  validate :blueprint_version_is_draft

  private

  def targets_are_in_same_framework
    return if blueprint_item.blank? || competency_item.blank?
    return if blueprint_item.blueprint_version.competency_framework_id == competency_item.competency_framework_id

    errors.add(:competency_item, "harus berasal dari framework versi blueprint")
  end

  def indicator_matches_competency
    return if competency_indicator.blank? || competency_item.blank?
    return if competency_indicator.competency_item_id == competency_item_id

    errors.add(:competency_indicator, "harus merupakan indikator kompetensi yang dipetakan")
  end

  def blueprint_version_is_draft
    return if blueprint_item&.blueprint_version&.status == "draft"
    return if persisted? && !changed?

    errors.add(:base, "Pemetaan komponen terbit hanya dapat diubah melalui versi draf")
  end
end
