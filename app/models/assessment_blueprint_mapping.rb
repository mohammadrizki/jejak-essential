# frozen_string_literal: true

# Menggantikan competency_mapping JSONB bebas teks: relasi FK ke kompetensi
# sungguhan, bukan label bebas yang bisa typo.
class AssessmentBlueprintMapping < ApplicationRecord
  include CappedWeight

  belongs_to :assessment_blueprint
  belongs_to :competency_item

  validates :weight, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :competency_item_id, uniqueness: { scope: :assessment_blueprint_id }
  validate :competency_belongs_to_blueprint_program
  caps_weight_total_by :assessment_blueprint_id, label: "blueprint"

  private

  def competency_belongs_to_blueprint_program
    return if competency_item.blank? || assessment_blueprint.blank?
    return if competency_item.competency_framework.study_program_id == assessment_blueprint.study_program_id

    errors.add(:competency_item, "harus berasal dari Peta Kompetensi program studi blueprint")
  end
end
