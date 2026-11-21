# frozen_string_literal: true

class AddEpaKsaAndScaleTargets < ActiveRecord::Migration[8.1]
  def change
    add_column :epa_competencies, :ksa_dimension, :string
    add_column :epa_competencies, :is_prerequisite, :boolean, default: false, null: false
    add_column :epa_competencies, :minimum_attainment_level, :integer
    add_column :epa_competencies, :is_critical, :boolean, default: false, null: false
    add_check_constraint :epa_competencies,
      "ksa_dimension IS NULL OR ksa_dimension IN ('knowledge', 'skill', 'attitude')",
      name: "chk_epa_competency_ksa", validate: false
    add_check_constraint :epa_competencies,
      "minimum_attainment_level IS NULL OR minimum_attainment_level BETWEEN 1 AND 5",
      name: "chk_epa_competency_minimum_level", validate: false
    safety_assured do
      validate_check_constraint :epa_competencies, name: "chk_epa_competency_ksa"
      validate_check_constraint :epa_competencies, name: "chk_epa_competency_minimum_level"
    end

    add_column :epa_milestones, :supervision_level_id, :bigint
    add_column :blueprint_item_epas, :supervision_level_id, :bigint
    safety_assured do
      add_index :epa_milestones, :supervision_level_id
      add_index :blueprint_item_epas, :supervision_level_id
    end
    add_foreign_key :epa_milestones, :supervision_levels, validate: false
    add_foreign_key :blueprint_item_epas, :supervision_levels, validate: false
    safety_assured do
      validate_foreign_key :epa_milestones, :supervision_levels
      validate_foreign_key :blueprint_item_epas, :supervision_levels
    end
  end
end
