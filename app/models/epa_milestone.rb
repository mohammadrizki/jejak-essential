# frozen_string_literal: true

class EpaMilestone < ApplicationRecord
  STAGES = StudyProgram::LEVELS.keys.freeze

  belongs_to :epa
  belongs_to :supervision_level, optional: true

  validates :stage, :expected_level, presence: true
  validates :stage, inclusion: { in: STAGES }, uniqueness: { scope: :epa_id }
  validates :expected_level, numericality: { only_integer: true, greater_than: 0 }
  validate :target_scale_matches

  private

  def target_scale_matches
    return if supervision_level.blank?
    return if supervision_level.supervision_scale_version.use_case == "prospective_entrustment" &&
              supervision_level.ordinal == expected_level

    errors.add(:supervision_level, "harus memakai level prospektif yang sesuai dengan expected_level")
  end
end
