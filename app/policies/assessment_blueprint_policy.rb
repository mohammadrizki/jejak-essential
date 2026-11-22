# frozen_string_literal: true

class AssessmentBlueprintPolicy < ApplicationPolicy
  def index?
    user.has_role?("superadmin") || StudyProgram.ordered.any? do |program|
      user.has_permission?("curriculum.manage", study_program: program)
    end
  end
  alias create? index?
  alias new? index?

  def artifact_map?
    return record_accessible_to_student? if active_role_code == "mahasiswa"

    return index? if record.is_a?(Class)

    record.is_a?(AssessmentBlueprint) && user.has_permission?("curriculum.manage", study_program: record.study_program)
  end

  def show?
    record.is_a?(AssessmentBlueprint) && (user.has_role?("superadmin") ||
      user.has_permission?("curriculum.manage", study_program: record.study_program))
  end

  def update?
    record.is_a?(AssessmentBlueprint) && (user.has_role?("superadmin") ||
      user.has_permission?("curriculum.manage", study_program: record.study_program))
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
