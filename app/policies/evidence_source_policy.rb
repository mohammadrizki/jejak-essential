# frozen_string_literal: true

class EvidenceSourcePolicy < ApplicationPolicy
  def index?
    UserAssignment.active.where(user: user, assignment_role: "evidence_reviewer").exists?
  end

  def validate?
    reviewable? && !imported_by_current_user?
  end

  def reject?
    validate?
  end

  class Scope < Scope
    def resolve
      base = scope.where(source_type: "external", validation_status: "unverified")
      return base.none unless user
      base = base.where("metadata ->> 'jejak_imported_by_id' IS DISTINCT FROM ?", user.id.to_s)
      assignments = UserAssignment.active.where(user: user, assignment_role: "evidence_reviewer")
      program_ids = assignments.where(scope_type: "StudyProgram").pluck(:scope_id)
      student_ids = assignments.where(scope_type: "User").pluck(:scope_id)
      student_ids.concat(User.where(study_program_id: program_ids).pluck(:id)) if program_ids.any?
      rotation_ids = assignments.where(scope_type: "ClinicalRotation").pluck(:scope_id)
      student_ids.concat(ClinicalRotation.where(id: rotation_ids).pluck(:user_id)) if rotation_ids.any?
      return base.none if student_ids.empty?

      base = base.where(student_id: student_ids.uniq)

      ids = base.includes(:student).select do |source|
        AssignmentAuthorization.assigned?(user: user, role: "evidence_reviewer", student: source.student, object: source)
      end.map(&:id)
      scope.where(id: ids)
    end
  end

  private

  def reviewable?
    record.is_a?(EvidenceSource) && record.source_type == "external" && record.validation_status == "unverified" &&
      AssignmentAuthorization.assigned?(user: user, role: "evidence_reviewer", student: record.student, object: record)
  end

  def imported_by_current_user?
    record.metadata.to_h["jejak_imported_by_id"].to_s == user.id.to_s
  end
end
