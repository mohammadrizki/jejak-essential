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
    assessed_on = assessed_at.to_date
    return false unless rotation.start_date <= assessed_on && rotation.end_date >= assessed_on

    built_in = (assessor.has_role?("dosen") || assessor.has_role?("preseptor")) && rotation.preceptor_id == assessor.id
    assigned = UserAssignment.active.where(user: assessor, assignment_role: "wpba_assessor").any? do |assignment|
      assignment.matches?(role: "wpba_assessor", student: student, object: rotation)
    end
    built_in || assigned
  end

  def self.rotations_for(assessor)
    return ClinicalRotation.none if assessor.blank?

    academic_assessor = assessor.has_role?("dosen") || assessor.has_role?("preseptor")
    rotations = academic_assessor ? ClinicalRotation.where(preceptor_id: assessor.id) : ClinicalRotation.none
    assignments = UserAssignment.active.where(user: assessor, assignment_role: "wpba_assessor")
    ids = assignments.filter_map do |assignment|
      case assignment.scope_type
      when "User" then ClinicalRotation.where(user_id: assignment.scope_id).pluck(:id)
      when "StudyProgram" then ClinicalRotation.joins(:user).where(users: { study_program_id: assignment.scope_id }).pluck(:id)
      when "ClinicalRotation" then assignment.scope_id
      else assignment.study_program_id && ClinicalRotation.joins(:user)
        .where(users: { study_program_id: assignment.study_program_id }).pluck(:id)
      end
    end.flatten
    rotations.or(ClinicalRotation.where(id: ids)).distinct
  end

  def self.wpba_enabled_rotations_for(assessor)
    rotations = rotations_for(assessor).includes(user: :study_program)
    enabled_ids = rotations.filter_map do |rotation|
      rotation.id if ModuleConfiguration.for(rotation.user.study_program).enabled?("wpba")
    end
    ClinicalRotation.where(id: enabled_ids)
  end
end
