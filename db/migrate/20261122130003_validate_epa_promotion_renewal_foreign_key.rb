# frozen_string_literal: true

class ValidateEpaPromotionRenewalForeignKey < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :epa_promotions, column: :renewal_of_decision_id
  end
end
