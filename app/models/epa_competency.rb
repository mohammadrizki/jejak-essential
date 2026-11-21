# frozen_string_literal: true

class EpaCompetency < ApplicationRecord
  belongs_to :epa
  belongs_to :competency_item
  belongs_to :competency_indicator, optional: true

  KSA_DIMENSIONS = %w[knowledge skill attitude].freeze

  validates :competency_item_id, uniqueness: { scope: %i[epa_id competency_indicator_id] }
  validates :ksa_dimension, inclusion: { in: KSA_DIMENSIONS }, allow_nil: true
  validates :contribution, inclusion: { in: %w[supporting important critical] }
  validates :minimum_attainment_level, inclusion: { in: 1..5 }, allow_nil: true
  validates :minimum_attainment_level, :ksa_dimension, presence: true, if: :is_prerequisite?
  validate :framework_matches
  validate :indicator_matches_competency

  private

  def framework_matches
    return if epa.blank? || competency_item.blank?
    return if epa.competency_framework_id == competency_item.competency_framework_id

    errors.add(:competency_item, "harus berasal dari framework EPA")
  end

  def indicator_matches_competency
    return if competency_indicator.blank? || competency_item.blank?
    return if competency_indicator.competency_item_id == competency_item_id

    errors.add(:competency_indicator, "harus merupakan indikator kompetensi yang dipetakan")
  end
end
