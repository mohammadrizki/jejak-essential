# frozen_string_literal: true

class DopsEvaluationPolicy < ApplicationPolicy
  def show?
    record.student_id == user.id || record.evaluator_id == user.id || assigned_to_record?
  end

  def create?
    user.has_role?("dosen") || user.has_role?("preseptor") ||
      UserAssignment.active.where(user: user, assignment_role: "wpba_assessor").exists?
  end
  alias new? create?

  def create_for_assigned_student?
    AssessmentAssignment.assigned?(assessor: user, student: record.student,
      rotation: record.clinical_rotation, assessed_at: record.evaluated_at || Date.current)
  end

  def update?
    !record.submitted? && record.evaluator_id == user.id && assigned_to_record?
  end
  alias edit? update?

  def correct?
    record.submitted? && assigned_to_record? && !record.corrections.exists?
  end

  # Penilai/admin menghapus; mahasiswa hanya membatalkan permintaannya
  # sendiri selama penilai belum mulai mengisi.
  def destroy?
    update? || (record.student_id == user.id && record.requested?)
  end
  alias submit? update?

  class Scope < Scope
    def resolve
      own_records = scope.where("student_id = :id OR evaluator_id = :id", id: user.id)
      rotations = AssessmentAssignment.rotations_for(user)
      own_records.or(scope.where(clinical_rotation_id: rotations.select(:id)))
    end
  end

  private

  def assigned_to_record?
    AssessmentAssignment.assigned?(assessor: user, student: record.student,
      rotation: record.clinical_rotation, assessed_at: record.evaluated_at)
  end
end
