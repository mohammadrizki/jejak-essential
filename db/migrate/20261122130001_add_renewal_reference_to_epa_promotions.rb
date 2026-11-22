# frozen_string_literal: true

class AddRenewalReferenceToEpaPromotions < ActiveRecord::Migration[8.1]
  def change
    add_column :epa_promotions, :renewal_of_decision_id, :bigint
    safety_assured do
      add_index :epa_promotions, :renewal_of_decision_id, name: "idx_epa_promotions_renewal_decision"
    end
  end
end
