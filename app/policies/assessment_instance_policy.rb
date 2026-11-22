# frozen_string_literal: true

# Satu percobaan asesmen beserta dokumen dan evaluasi dirinya. Boleh dibuka
# pemilik, penguji yang tercatat, atau pengajar/Kaprodi yang berwenang melihat
# mahasiswa itu. Admin teknis tidak memperoleh akses dari role saja.
class AssessmentInstancePolicy < ApplicationPolicy
  def show?
    record.student_id == user.id || record.examiner_id == user.id ||
      ((user.has_role?("dosen") || user.has_role?("preseptor")) && user.can_view_student?(record.student)) ||
      (user.has_role?("kaprodi") && user.study_program_id.present? &&
        record.student.study_program_id == user.study_program_id)
  end
end
