# frozen_string_literal: true

class CompetencyFrameworkPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    return true if user.has_role?("admin")
    return false unless record.is_a?(CompetencyFramework)

    record.study_program_id.present? && record.study_program_id == user.study_program_id
  end

  def manage?
    return true if user.has_role?("admin")
    return false unless user.has_role?("kaprodi")

    program_id = record.is_a?(Class) ? user.study_program_id : record.study_program_id
    program_id.present? && program_id == user.study_program_id
  end
  alias create? manage?
  alias new? manage?
  alias update? manage?
  alias edit? manage?
  alias destroy? manage?
end
