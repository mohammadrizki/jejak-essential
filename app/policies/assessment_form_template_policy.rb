# frozen_string_literal: true

# Seluruh Form Builder — termasuk membuka dan mengisi formulir — hanya untuk
# kaprodi dan admin. Penguji tetap mengisi rubrik template lewat Lembar
# Penguji (ExaminerEvaluationsController), yang tidak melewati policy ini.
class AssessmentFormTemplatePolicy < ApplicationPolicy
  def manage?
    return true if user.has_role?("admin")
    user.has_role?("kaprodi") && user.study_program_id.present? && record.study_program_id == user.study_program_id
  end

  def index?
    user.can_manage_assessment_forms? && (!user.has_role?("kaprodi") || user.study_program_id.present?)
  end

  def show?
    return true if user.has_role?("admin")
    user.has_role?("kaprodi") && user.study_program_id.present? &&
      (record.study_program_id.nil? || record.study_program_id == user.study_program_id)
  end

  def create?
    user.has_role?("admin") || (user.has_role?("kaprodi") && user.study_program_id.present?)
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
      return scope.all if user.has_role?("admin")
      return scope.none unless user.has_role?("kaprodi") && user.study_program_id.present?

      scope.where(study_program_id: [nil, user.study_program_id])
    end
  end
end
