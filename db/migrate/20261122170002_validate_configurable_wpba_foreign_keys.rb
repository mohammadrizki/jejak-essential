# frozen_string_literal: true

class ValidateConfigurableWpbaForeignKeys < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :wpba_observations, column: :corrects_id
    validate_foreign_key :evidence_records, column: :wpba_observation_id
  end
end
