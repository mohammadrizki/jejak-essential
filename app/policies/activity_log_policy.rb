# frozen_string_literal: true

# Logbook Kegiatan (kegiatan non-kasus: kuliah, tutorial, jaga, dsb.) —
# meniru pola ClinicalCasePolicy: pemilik & pengajar boleh melihat, hanya
# pengajar (bukan pemilik sendiri) yang boleh memverifikasi.
class ActivityLogPolicy < ApplicationPolicy
  def show?
    owner? || AssignmentAuthorization.assigned?(user: user, role: "logbook_verifier", student: record.user)
  end

  def update?
    owner?
  end

  # Kegiatan terverifikasi sudah menjadi bukti yang disahkan pembimbing.
  def destroy?
    owner? && !record.verified?
  end

  def verify?
    !owner? && user.can_verify_clinical_cases? && !record.verified? &&
      AssignmentAuthorization.assigned?(user: user, role: "logbook_verifier", student: record.user)
  end

  class Scope < Scope
    def resolve
      if user.can_verify_clinical_cases?
        assigned_ids = UserAssignment.active.where(user: user, assignment_role: "logbook_verifier").filter_map do |assignment|
          case assignment.scope_type
          when "User" then assignment.scope_id
          when "StudyProgram" then User.where(study_program_id: assignment.scope_id).pluck(:id)
          when "ClinicalRotation" then ClinicalRotation.where(id: assignment.scope_id).pluck(:user_id)
          else assignment.study_program_id && User.where(study_program_id: assignment.study_program_id).pluck(:id)
          end
        end.flatten.uniq
        scope.where(user_id: assigned_ids)
      else
        scope.owned_by(user)
      end
    end
  end

  private

  def owner?
    record.user_id == user.id
  end
end
