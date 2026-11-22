# frozen_string_literal: true

class ValidateEpaPanelGovernanceForeignKeys < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :epa_promotions, column: :finalized_by_id
    validate_check_constraint :epa_promotion_review_events, name: "chk_epa_panel_event_kind"
  end
end
