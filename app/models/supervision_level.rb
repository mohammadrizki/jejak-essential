# frozen_string_literal: true

class SupervisionLevel < ApplicationRecord
  belongs_to :supervision_scale_version
  has_many :epa_observations, dependent: :restrict_with_error
  has_many :entrustment_decisions, dependent: :restrict_with_error

  validates :ordinal, numericality: { only_integer: true, greater_than: 0 }
  validates :code, :label, :description, presence: true
  validates :ordinal, uniqueness: { scope: :supervision_scale_version_id }
  validates :code, uniqueness: { scope: :supervision_scale_version_id }
  validate :level_is_immutable_when_used, on: :update
  before_destroy :prevent_destroy_when_used

  private

  def level_is_immutable_when_used
    return unless epa_observations.exists? || entrustment_decisions.exists? ||
                  EpaMilestone.exists?(supervision_level_id: id) || BlueprintItemEpa.exists?(supervision_level_id: id)

    errors.add(:base, "Level skala yang sudah dipakai tidak dapat diubah; buat versi baru")
  end

  def prevent_destroy_when_used
    return unless epa_observations.exists? || entrustment_decisions.exists? ||
                  EpaMilestone.exists?(supervision_level_id: id) || BlueprintItemEpa.exists?(supervision_level_id: id)

    errors.add(:base, "Level skala yang sudah dipakai tidak dapat dihapus")
    throw :abort
  end
end
