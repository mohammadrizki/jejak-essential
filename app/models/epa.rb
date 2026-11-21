# frozen_string_literal: true

class Epa < ApplicationRecord
  belongs_to :competency_framework
  has_many :epa_competencies, dependent: :destroy
  has_many :competency_items, through: :epa_competencies
  has_many :blueprint_item_epas, dependent: :destroy
  has_many :blueprint_items, through: :blueprint_item_epas
  has_many :evidence_requirements, dependent: :restrict_with_error
  has_many :entrustment_decisions, dependent: :restrict_with_error
  has_many :epa_milestones, dependent: :destroy
  has_many :epa_observations, dependent: :restrict_with_error
  has_many :epa_promotions, dependent: :restrict_with_error

  validates :code, :title, presence: true
  validates :code, uniqueness: { scope: :competency_framework_id }
  validates :status, inclusion: { in: %w[draft published archived] }
  validate :available_at_framework_stage
  validate :framework_is_draft_for_changes
  before_destroy :prevent_published_epa_deletion

  private

  def available_at_framework_stage
    return if competency_framework.blank? || competency_framework.education_stage != "undergraduate"
    return if code.to_s.start_with?("LEGACY-")

    errors.add(:base, "EPA hanya tersedia pada tahap Profesi, Spesialis, dan Subspesialis")
  end

  def framework_is_draft_for_changes
    return if competency_framework&.status == "draft"
    return if persisted? && !changed?

    errors.add(:base, "EPA framework terbit hanya dapat diubah melalui versi draf")
  end

  def prevent_published_epa_deletion
    return if competency_framework&.status == "draft"

    errors.add(:base, "EPA pada framework terbit tidak dapat dihapus")
    throw :abort
  end
end
