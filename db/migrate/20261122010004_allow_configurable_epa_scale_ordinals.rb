# frozen_string_literal: true

class AllowConfigurableEpaScaleOrdinals < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :epa_milestones, name: "chk_epa_milestone_level"
    add_check_constraint :epa_milestones, "expected_level >= 1", name: "chk_epa_milestone_level", validate: false
    remove_check_constraint :blueprint_item_epas, name: "chk_blueprint_epa_expected_level"
    add_check_constraint :blueprint_item_epas, "expected_level IS NULL OR expected_level >= 1",
      name: "chk_blueprint_epa_expected_level", validate: false
    safety_assured do
      validate_check_constraint :epa_milestones, name: "chk_epa_milestone_level"
      validate_check_constraint :blueprint_item_epas, name: "chk_blueprint_epa_expected_level"
    end
  end
end
