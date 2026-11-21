# frozen_string_literal: true

class CompetencyIndicator < ApplicationRecord
  belongs_to :competency_item
  has_many :blueprint_item_competencies, dependent: :restrict_with_error
  has_many :epa_competencies, dependent: :restrict_with_error
  has_many :evidence_requirements, dependent: :restrict_with_error

  validates :description, :code, presence: true
  validates :performance_level, presence: true, if: :new_record?
  validates :code, uniqueness: { scope: :competency_item_id }
  validate :code_is_unique_across_framework_entries
  before_validation :assign_code
  validate :framework_is_draft
  before_destroy :framework_is_draft_for_deletion

  private

  def assign_code
    return if code.present? || competency_item.blank?

    base = "#{competency_item.code}-IND"
    framework = competency_item.competency_framework
    existing = framework.competency_items.pluck(:code).compact + framework.competency_indicators.where.not(id: id).pluck(:code).compact
    candidate = base
    suffix = 2
    while existing.include?(candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end
    self.code = candidate
  end

  def code_is_unique_across_framework_entries
    return if code.blank? || competency_item.blank?

    framework = competency_item.competency_framework
    item_code_used = framework.competency_items.where(code: code).exists?
    indicator_code_used = framework.competency_indicators.where(code: code).where.not(id: id).exists?
    return unless item_code_used || indicator_code_used

    errors.add(:code, "harus unik dalam framework")
  end

  def framework_is_draft
    return if competency_item&.competency_framework&.status == "draft"
    return if persisted? && !changed?

    errors.add(:base, "Indikator pada framework terbit hanya dapat diubah melalui versi draf")
  end

  def framework_is_draft_for_deletion
    return if competency_item&.competency_framework&.status == "draft"

    errors.add(:base, "Indikator pada framework terbit tidak dapat dihapus")
    throw :abort
  end
end
