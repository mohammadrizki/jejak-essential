# frozen_string_literal: true

class AssessmentFormSubmissionPolicy < ApplicationPolicy
  def show?
    record.respondent_id == user.id || record.subject_user_id == user.id || manager_can_access_record?
  end

  class Scope < Scope
    def resolve
      if user.has_role?("superadmin")
        scope.all
      elsif user.programs_with_permission("curriculum.manage").any?
        program_users = User.where(study_program_id: user.programs_with_permission("curriculum.manage").map(&:id)).select(:id)
        scope.where(respondent_id: program_users).or(scope.where(subject_user_id: program_users))
      else
        scope.where("respondent_id = :id OR subject_user_id = :id", id: user.id)
      end
    end
  end

  private

  def manager_can_access_record?
    return false unless user.can_manage_assessment_forms?
    return true if user.has_role?("superadmin")

    program_ids = user.programs_with_permission("curriculum.manage").map(&:id)
    record.respondent&.study_program_id.in?(program_ids) || record.subject_user&.study_program_id.in?(program_ids)
  end
end
