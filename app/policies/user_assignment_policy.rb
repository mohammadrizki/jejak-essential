# frozen_string_literal: true

class UserAssignmentPolicy < ApplicationPolicy
  def index?
    user.has_role?("superadmin") || accessible_program_ids.any?
  end

  def create?
    index?
  end

  def destroy?
    user.has_role?("superadmin") || accessible_program_ids.include?(record.study_program_id)
  end

  private

  def accessible_program_ids
    StudyProgram.pluck(:id).select { |id| user.has_permission?("assignments.manage", study_program: StudyProgram.find(id)) }
  end

  class Scope < Scope
    def resolve
      return scope.all if user.has_role?("superadmin")
      ids = StudyProgram.pluck(:id).select do |id|
        user.has_permission?("assignments.manage", study_program: StudyProgram.find(id))
      end
      return scope.where(study_program_id: ids)
    end
  end
end
