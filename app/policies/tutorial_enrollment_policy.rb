# frozen_string_literal: true

class TutorialEnrollmentPolicy < ApplicationPolicy
  def create?
    program = record.is_a?(TutorialEnrollment) ? record.user&.study_program : nil
    user.has_role?("superadmin") || (program ? user.permitted_for_program?(program, "assignments.manage") : user.programs_with_permission("assignments.manage").any?)
  end
  alias new? create?

  def update?
    create?
  end
  alias edit? update?

  def destroy?
    create?
  end

  class Scope < Scope
    def resolve
      if user.has_role?("superadmin")
        scope.all
      else
        program_ids = user.programs_with_permission("assignments.manage").map(&:id)
        scope.where(user_id: User.where(study_program_id: program_ids).select(:id))
          .or(scope.where("tutorial_enrollments.user_id = :id OR tutorial_enrollments.tutor_id = :id", id: user.id))
      end
    end
  end
end
