# frozen_string_literal: true

class AddEpaPanelQuorumToStudyPrograms < ActiveRecord::Migration[8.1]
  def change
    add_column :study_programs, :epa_panel_quorum, :integer, null: false, default: 1
    add_check_constraint :study_programs, "epa_panel_quorum BETWEEN 1 AND 10",
      name: "chk_study_program_epa_panel_quorum", validate: false
  end
end
