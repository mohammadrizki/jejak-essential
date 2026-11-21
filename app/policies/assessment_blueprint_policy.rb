# frozen_string_literal: true

class AssessmentBlueprintPolicy < ApplicationPolicy
  def index?
    user.has_role?("admin") || user.has_role?("kaprodi")
  end
  alias create? index?
  alias new? index?

  def show?
    return true if user.has_role?("admin")

    user.has_role?("kaprodi") && record.is_a?(AssessmentBlueprint) &&
      record.study_program_id == user.study_program_id
  end

  def update?
    return true if user.has_role?("admin")

    user.has_role?("kaprodi") && record.is_a?(AssessmentBlueprint) &&
      record.study_program_id == user.study_program_id
  end
  alias edit? update?
  alias destroy? update?
end
