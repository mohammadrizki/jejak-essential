# frozen_string_literal: true

class FinalProjectPolicy < ApplicationPolicy
  def show?
    owner? || supervisor? || academic_instructor?
  end

  def create?
    user.has_role?("mahasiswa")
  end
  alias new? create?

  def update?
    owner? || supervisor?
  end
  alias edit? update?

  def destroy?
    owner? && record.status == "proposal"
  end

  def manage_milestones?
    update?
  end

  # Akun multi-peran tidak menguji tugas akhirnya sendiri.
  def score?
    academic_instructor? && !owner?
  end

  class Scope < Scope
    # Dosen (bukan cuma pembimbing) bisa jadi penguji siapa saja, jadi
    # diberi akses lihat semua tugas akhir — bukan cuma yang dibimbingnya.
    def resolve
      if user.has_role?("dosen") || user.has_role?("preseptor")
        scope.all
      else
        scope.where(student: user).or(scope.where(supervisor_id: user.id))
      end
    end
  end

  private

  def owner?
    record.student_id == user.id
  end

  def supervisor?
    record.supervisor_id == user.id
  end

  def academic_instructor?
    user.has_role?("dosen") || user.has_role?("preseptor")
  end
end
