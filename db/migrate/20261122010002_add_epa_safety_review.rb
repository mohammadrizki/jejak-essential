# frozen_string_literal: true

class AddEpaSafetyReview < ActiveRecord::Migration[8.1]
  def change
    add_column :epa_observations, :safety_resolution, :text
    add_column :epa_observations, :safety_resolved_at, :datetime
    add_column :epa_observations, :safety_resolved_by_id, :bigint
    safety_assured { add_index :epa_observations, :safety_resolved_by_id }
    add_foreign_key :epa_observations, :users, column: :safety_resolved_by_id, validate: false
    safety_assured { validate_foreign_key :epa_observations, :users, column: :safety_resolved_by_id }
    add_check_constraint :epa_observations,
      "(safety_resolved_at IS NULL AND safety_resolved_by_id IS NULL AND safety_resolution IS NULL) OR " \
      "(safety_resolved_at IS NOT NULL AND safety_resolved_by_id IS NOT NULL AND length(btrim(safety_resolution)) >= 10)",
      name: "chk_epa_safety_resolution", validate: false
    safety_assured { validate_check_constraint :epa_observations, name: "chk_epa_safety_resolution" }
  end
end
