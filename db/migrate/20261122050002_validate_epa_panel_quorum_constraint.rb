# frozen_string_literal: true

class ValidateEpaPanelQuorumConstraint < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :study_programs, name: "chk_study_program_epa_panel_quorum"
  end
end
