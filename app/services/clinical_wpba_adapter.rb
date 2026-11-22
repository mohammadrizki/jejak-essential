# frozen_string_literal: true

# Canonical file/API adapter for an institution's external workplace-based
# observation system. Vendor-specific transport and field mapping remain at
# the institution edge; this adapter accepts only JEJAK's canonical evidence
# payload and does not mark imported observations as validated.
class ClinicalWpbaAdapter < ExternalEvidenceAdapter
  private

  def source_system = "clinical_wpba"
end
