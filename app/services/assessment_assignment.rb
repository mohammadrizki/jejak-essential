# frozen_string_literal: true

# Uses the clinical placement assignment already present in JEJAK as the
# authoritative scope for workplace assessment. This is deliberately a
# narrow adapter; other assignment types can be added without embedding role
# checks in WPBA controllers.
class AssessmentAssignment
  def self.assigned?(assessor:, student:, rotation:, assessed_at: Date.current)
    return false if assessor.blank? || student.blank? || rotation.blank?
    return false if assessor.id == student.id
    return false unless rotation.user_id == student.id
    return false unless rotation.preceptor_id == assessor.id
    assessed_on = assessed_at.to_date
    return false unless rotation.start_date <= assessed_on && rotation.end_date >= assessed_on

    assessor.instructor?
  end

  def self.rotations_for(assessor)
    return ClinicalRotation.none unless assessor&.instructor?

    ClinicalRotation.where(preceptor_id: assessor.id)
  end
end
