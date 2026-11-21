# frozen_string_literal: true

class CompetencyFrameworkPolicy < ApplicationPolicy
  def index?
    true
  end
  alias show? index?

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
