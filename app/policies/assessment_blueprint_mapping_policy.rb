# frozen_string_literal: true

class AssessmentBlueprintMappingPolicy < ApplicationPolicy
  def create?
    record.is_a?(AssessmentBlueprintMapping) &&
      user.permitted_for_program?(record.assessment_blueprint.study_program, "curriculum.manage")
  end
  alias destroy? create?
end
