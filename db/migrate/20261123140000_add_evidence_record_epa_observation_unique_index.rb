# frozen_string_literal: true

class AddEvidenceRecordEpaObservationUniqueIndex < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      add_index :evidence_records, [ :evidence_requirement_id, :epa_observation_id ], unique: true,
        where: "epa_observation_id IS NOT NULL", name: "idx_evidence_record_epa_observation_once"
    end
  end
end
