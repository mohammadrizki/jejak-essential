# frozen_string_literal: true

class UserAssignmentPolicy < ApplicationPolicy
  def index?
    user.has_role?("admin") || (user.has_role?("kaprodi") && user.study_program_id.present?)
  end

  def create?
    index?
  end

  def destroy?
    index? && (user.has_role?("admin") || record.study_program_id == user.study_program_id)
  end

  class Scope < Scope
    def resolve
      return scope.all if user.has_role?("admin")
      return scope.where(study_program_id: user.study_program_id) if user.has_role?("kaprodi")

      scope.none
    end
  end
end
