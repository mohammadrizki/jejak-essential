# frozen_string_literal: true

class CompetencyItemPolicy < ApplicationPolicy
  def manage?
    framework = record.is_a?(CompetencyItem) ? record.competency_framework : nil
    user.permitted_for_program?(framework&.study_program, "curriculum.manage")
  end
  alias create? manage?
  alias new? manage?
  alias update? manage?
  alias edit? manage?
  alias destroy? manage?
end
