# frozen_string_literal: true

class CompetencyItemPolicy < ApplicationPolicy
  def manage?
    framework = record.is_a?(CompetencyItem) ? record.competency_framework : nil
    user.has_role?("admin") ||
      (user.has_role?("kaprodi") && framework&.study_program_id == user.study_program_id)
  end
  alias create? manage?
  alias new? manage?
  alias update? manage?
  alias edit? manage?
  alias destroy? manage?
end
