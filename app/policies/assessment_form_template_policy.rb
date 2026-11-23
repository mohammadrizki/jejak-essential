# frozen_string_literal: true

# Seluruh Form Builder — termasuk membuka dan mengisi formulir — hanya untuk
# kaprodi dan admin. Penguji tetap mengisi rubrik template lewat Lembar
# Penguji (ExaminerEvaluationsController), yang tidak melewati policy ini.
class AssessmentFormTemplatePolicy < ApplicationPolicy
  def manage?
    return user.has_role?("superadmin") if record.study_program_id.blank?

    user.permitted_for_program?(record.study_program, "curriculum.manage")
  end

  def index?
    user.has_role?("superadmin") || user.programs_with_permission("curriculum.manage").any?
  end

  def show?
    return user.has_role?("superadmin") || user.programs_with_permission("curriculum.manage").any? if record.study_program_id.blank?

    user.permitted_for_program?(record.study_program, "curriculum.manage")
  end

  def create?
    user.has_role?("superadmin") || user.programs_with_permission("curriculum.manage").any?
  end
  alias new? create?

  def update?
    manage?
  end
  alias edit? update?

  def destroy?
    manage?
  end

  class Scope < Scope
    def resolve
      return scope.all if user.has_role?("superadmin")

      scope.where(study_program_id: user.programs_with_permission("curriculum.manage").map(&:id))
        .or(scope.where(study_program_id: nil))
    end
  end
end
