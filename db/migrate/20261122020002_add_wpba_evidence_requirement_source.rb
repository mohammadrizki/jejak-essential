# frozen_string_literal: true

class AddWpbaEvidenceRequirementSource < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_check_constraint :evidence_requirements, name: "chk_evidence_requirement_source"
      add_check_constraint :evidence_requirements,
        "source_type IN ('assessment', 'wpba', 'logbook', 'portfolio', 'reflection', 'other', 'epa_observation')",
        name: "chk_evidence_requirement_source", validate: false
    end

    safety_assured do
      validate_check_constraint :evidence_requirements, name: "chk_evidence_requirement_source"
    end
  end
end
