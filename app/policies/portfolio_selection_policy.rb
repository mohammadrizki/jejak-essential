# frozen_string_literal: true

class PortfolioSelectionPolicy < ApplicationPolicy
  def create?
    record.artifact_submission&.student_id == user.id
  end

  def destroy?
    record.student_id == user.id
  end

  def show?
    return true if record.student_id == user.id
    return false unless record.visibility == "assigned_reviewers"

    AssignmentAuthorization.assigned?(user: user, role: "artifact_reviewer", student: record.student)
  end

  def show_student?
    return true if record.student_id == user.id

    AssignmentAuthorization.assigned?(user: user, role: "artifact_reviewer", student: record.student)
  end
end
