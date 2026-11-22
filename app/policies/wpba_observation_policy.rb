# frozen_string_literal: true

class WpbaObservationPolicy < ApplicationPolicy
  def show?
    record.student_id == user.id || record.observer_id == user.id || assigned_to_record?
  end

  def create?
    user.has_role?("dosen") || user.has_role?("preseptor") ||
      UserAssignment.active.where(user: user, assignment_role: "wpba_assessor").exists?
  end
  alias new? create?

  def create_for_assigned_student?
    AssessmentAssignment.assigned?(assessor: user, student: record.student,
      rotation: record.clinical_rotation, assessed_at: record.observed_at || Date.current)
  end

  def update?
    record.status == "draft" && record.observer_id == user.id && assigned_to_record?
  end
  alias edit? update?
  alias submit? update?
  alias destroy? update?

  def correct?
    record.submitted? && assigned_to_record? && !record.corrections.exists?
  end

  class Scope < Scope
    def resolve
      owned = scope.where("student_id = :id OR observer_id = :id", id: user.id)
      rotations = AssessmentAssignment.rotations_for(user)
      owned.or(scope.where(clinical_rotation_id: rotations.select(:id)))
    end
  end

  private

  def assigned_to_record?
    AssessmentAssignment.assigned?(assessor: user, student: record.student,
      rotation: record.clinical_rotation, assessed_at: record.observed_at)
  end
end
