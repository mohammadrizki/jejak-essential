# frozen_string_literal: true

class ClinicalRotationPolicy < ApplicationPolicy
  def show?
    record.user_id == user.id || record.preceptor_id == user.id ||
      user.permitted_for_program?(record.user&.study_program, "assignments.manage")
  end

  def create?
    program = record.is_a?(ClinicalRotation) ? record.user&.study_program : nil
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
          .or(scope.where("clinical_rotations.user_id = :id OR clinical_rotations.preceptor_id = :id", id: user.id))
      end
    end
  end
end
