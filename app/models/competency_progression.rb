# frozen_string_literal: true

class CompetencyProgression < ApplicationRecord
  RELATIONSHIP_TYPES = %w[prerequisite supports develops_into].freeze

  belongs_to :source_competency, class_name: "CompetencyItem"
  belongs_to :target_competency, class_name: "CompetencyItem"

  validates :relationship_type, inclusion: { in: RELATIONSHIP_TYPES },
                                uniqueness: { scope: %i[source_competency_id target_competency_id] }
  validate :competencies_share_framework

  private

  def competencies_share_framework
    return if source_competency.blank? || target_competency.blank?
    return if source_competency.competency_framework_id == target_competency.competency_framework_id

    errors.add(:target_competency, "harus berada dalam framework kompetensi yang sama")
  end
end
