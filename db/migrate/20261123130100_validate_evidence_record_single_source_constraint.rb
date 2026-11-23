# frozen_string_literal: true

class ValidateEvidenceRecordSingleSourceConstraint < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :evidence_records, name: "chk_evidence_record_single_source"
  end
end
