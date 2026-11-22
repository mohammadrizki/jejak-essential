# frozen_string_literal: true

class AssessmentBlueprintPolicy < ApplicationPolicy
  def index?
    user.has_role?("admin") || user.has_role?("kaprodi")
  end
  alias create? index?
  alias new? index?

  def artifact_map?
    return true if user.has_role?("admin")
    return record_accessible_to_student? if active_role_code == "mahasiswa"

    user.has_role?("kaprodi") && record.is_a?(Class) && user.study_program_id.present?
  end

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

  private

  def active_role_code
    user.active_role&.code || user.roles.first&.code
  end

  def record_accessible_to_student?
    user.has_role?("mahasiswa") && user.study_program_id.present?
  end
end
