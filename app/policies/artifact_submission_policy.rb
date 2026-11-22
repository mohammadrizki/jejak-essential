# frozen_string_literal: true

class ArtifactSubmissionPolicy < ApplicationPolicy
  def index?
    user.has_role?("mahasiswa") || UserAssignment.active.exists?(user: user, assignment_role: "artifact_reviewer")
  end

  def show?
    record.student_id == user.id || reviewer_for?
  end

  def create?
    user.has_role?("mahasiswa")
  end

  def update?
    reviewer_for? && record.submitted?
  end

  def destroy?
    record.student_id == user.id && record.status == "submitted"
  end

  def resubmit?
    record.student_id == user.id && record.status == "rejected"
  end

  class Scope < Scope
    def resolve
      return scope.where(student: user) if user.has_role?("mahasiswa")
      assignments = UserAssignment.active.where(user: user, assignment_role: "artifact_reviewer")
      student_ids = assignments.filter_map do |assignment|
        case assignment.scope_type
        when "User" then assignment.scope_id
        when "StudyProgram" then User.where(study_program_id: assignment.scope_id).pluck(:id)
        when "ClinicalRotation" then ClinicalRotation.where(id: assignment.scope_id).pick(:user_id)
        else assignment.study_program_id && User.where(study_program_id: assignment.study_program_id).pluck(:id)
        end
      end.flatten.uniq
      scope.where(student_id: student_ids)
    end
  end

  private

  def reviewer_for?
    return false if record.student_id == user.id
    AssignmentAuthorization.assigned?(user: user, role: "artifact_reviewer", student: record.student, object: record)
  end

end
