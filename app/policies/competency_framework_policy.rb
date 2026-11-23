# frozen_string_literal: true

class CompetencyFrameworkPolicy < ApplicationPolicy
  def index?
    user.has_role?("mahasiswa") || user.has_role?("superadmin") || StudyProgram.ordered.any? do |program|
      user.has_permission?("curriculum.manage", study_program: program)
    end
  end

  def show?
    return false unless record.is_a?(CompetencyFramework)

    record.study_program_id.present? && (user.has_role?("superadmin") ||
      (user.has_role?("mahasiswa") && record.study_program_id == user.study_program_id) ||
      user.has_permission?("curriculum.manage", study_program: record.study_program) ||
      (record.study_program&.showcase? && curriculum_manager?))
  end

  def manage?
    if record.is_a?(Class)
      return user.has_role?("superadmin") || StudyProgram.ordered.any? do |program|
        user.has_permission?("curriculum.manage", study_program: program)
      end
    end

    record.is_a?(CompetencyFramework) && record.study_program.present? &&
      (user.has_role?("superadmin") || user.has_permission?("curriculum.manage", study_program: record.study_program))
  end
  alias create? manage?
  alias new? manage?
  alias update? manage?
  alias edit? manage?
  alias destroy? manage?

  private

  def curriculum_manager?
    user.has_role?("superadmin") || StudyProgram.ordered.any? do |program|
      user.has_permission?("curriculum.manage", study_program: program)
    end
  end
end
