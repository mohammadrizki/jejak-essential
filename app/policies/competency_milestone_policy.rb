# frozen_string_literal: true

class CompetencyMilestonePolicy < ApplicationPolicy
  def create?
    return user.programs_with_permission("curriculum.manage").any? if record.is_a?(Class)

    item = record.is_a?(CompetencyItem) ? record : record.competency_item
    return user.programs_with_permission("curriculum.manage").any? if item.blank?

    user.permitted_for_program?(item&.competency_framework&.study_program, "curriculum.manage")
  end
  alias destroy? create?
end
