# frozen_string_literal: true

class AddRenewalForeignKeyToEpaPromotions < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      add_foreign_key :epa_promotions, :entrustment_decisions,
        column: :renewal_of_decision_id, validate: false
    end
  end
end
