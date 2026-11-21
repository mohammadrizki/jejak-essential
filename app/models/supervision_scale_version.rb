# frozen_string_literal: true

class SupervisionScaleVersion < ApplicationRecord
  USE_CASES = %w[retrospective_observation prospective_entrustment].freeze

  has_many :supervision_levels, -> { order(:ordinal) }, dependent: :restrict_with_error

  validates :code, :name, :version_label, presence: true
  validates :code, uniqueness: { scope: :version_label }
  validates :use_case, inclusion: { in: USE_CASES }
  validate :version_is_immutable_when_used, on: :update
  before_destroy :prevent_destroy_when_used

  private

  def version_is_immutable_when_used
    return unless supervision_levels.joins(:epa_observations).exists? ||
                  supervision_levels.joins(:entrustment_decisions).exists? ||
                  EpaMilestone.where(supervision_level_id: supervision_levels.select(:id)).exists? ||
                  BlueprintItemEpa.where(supervision_level_id: supervision_levels.select(:id)).exists?

    errors.add(:base, "Versi skala yang sudah dipakai tidak dapat diubah; buat versi baru")
  end

  def prevent_destroy_when_used
    return unless supervision_levels.joins(:epa_observations).exists? ||
                  supervision_levels.joins(:entrustment_decisions).exists? ||
                  EpaMilestone.where(supervision_level_id: supervision_levels.select(:id)).exists? ||
                  BlueprintItemEpa.where(supervision_level_id: supervision_levels.select(:id)).exists?

    errors.add(:base, "Versi skala yang sudah dipakai tidak dapat dihapus")
    throw :abort
  end
end
