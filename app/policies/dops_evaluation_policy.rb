# frozen_string_literal: true

class DopsEvaluationPolicy < ApplicationPolicy
  def show?
    record.student_id == user.id || record.evaluator_id == user.id || user.has_role?("admin")
  end

  def create?
    user.instructor?
  end
  alias new? create?

  def create_for_assigned_student?
    AssessmentAssignment.assigned?(assessor: user, student: record.student,
      rotation: record.clinical_rotation, assessed_at: record.evaluated_at || Date.current)
  end

  def update?
    record.evaluator_id == user.id || user.has_role?("admin")
  end
  alias edit? update?

  # Penilai/admin menghapus; mahasiswa hanya membatalkan permintaannya
  # sendiri selama penilai belum mulai mengisi.
  def destroy?
    update? || (record.student_id == user.id && record.requested?)
  end
  alias submit? update?

  class Scope < Scope
    def resolve
      if user.has_role?("admin")
        scope.all
      else
        scope.where("student_id = :id OR evaluator_id = :id", id: user.id)
      end
    end
  end
end
