# frozen_string_literal: true

class BlueprintItem < ApplicationRecord
  belongs_to :blueprint_version
  belongs_to :assessment_method
  has_many :blueprint_item_competencies, dependent: :destroy
  has_many :competency_items, through: :blueprint_item_competencies
  has_many :blueprint_item_epas, dependent: :destroy
  has_many :epas, through: :blueprint_item_epas
  has_many :evidence_requirements, dependent: :restrict_with_error

  validates :code, :title, presence: true
  validates :code, uniqueness: { scope: :blueprint_version_id }
  validate :blueprint_version_is_draft
  before_destroy :blueprint_version_is_draft_for_deletion

  private

  def blueprint_version_is_draft
    return if blueprint_version&.status == "draft"
    return if persisted? && !changed?

    errors.add(:base, "Komponen pada blueprint terbit hanya dapat diubah melalui versi draf")
  end

  def blueprint_version_is_draft_for_deletion
    return if blueprint_version&.status == "draft"

    errors.add(:base, "Komponen versi terbit/arsip tidak dapat dihapus")
    throw :abort
  end
end
