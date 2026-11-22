# frozen_string_literal: true

class ClinicalCasePolicy < ApplicationPolicy
  # Draf hanya terlihat pemilik. Kasus kiriman hanya terlihat pemilik,
  # pembimbing/verifier yang tercatat, atau penilai yang ditugaskan.
  def show?
    owner? || (record.status != "draft" && (assigned_supervisor? || record.supervised_by?(user) || record.verified_by_id == user.id ||
      AssignmentAuthorization.assigned?(user: user, role: "clinical_case_verifier", student: record.user)))
  end

  def update?
    owner? && record.editable_by_owner?
  end

  def destroy?
    owner? && record.status == "draft"
  end

  def submit?
    owner? && record.editable_by_owner?
  end

  # Bukan cuma "punya peran dosen/admin" — akun yang kebetulan juga
  # menyandang peran mahasiswa (multi-peran diperbolehkan di app ini) tidak
  # boleh memverifikasi kasus miliknya sendiri. Kasus yang menandai
  # pembimbing hanya boleh diverifikasi pembimbing itu, bukan pengajar lain.
  def verify?
    !owner? && user.can_verify_clinical_cases? && record.status == "submitted" &&
      assigned_verifier?
  end

  def request_revision?
    verify?
  end

  def reject?
    verify?
  end

  # Hanya verifier yang tercatat atau penilai yang ditugaskan boleh membatalkan.
  def cancel_verification?
    !owner? && record.status == "verified" &&
      (record.verified_by_id == user.id || AssignmentAuthorization.assigned?(user: user,
        role: "clinical_case_verifier", student: record.user))
  end

  # Pemilik dan pembimbing yang boleh membuka kasus boleh berdiskusi.
  def comment?
    show?
  end

  # Break Glass membuka identitas pasien dengan alasan, bagi pengguna yang
  # sudah memiliki akses akademik sah ke kasus.
  def break_glass?
    show?
  end

  # Pembimbing kasus melihat identitas pasien tanpa Break Glass walau Privacy
  # Mode menyala; pengguna lain tetap lewat Break Glass.
  def view_patient_identity?
    show? && !owner? && record.supervised_by?(user)
  end

  def issue_consent?
    owner?
  end

  # CBD/Long Case hanya dari kasus milik sendiri yang sudah diajukan/diverifikasi.
  def initiate_assessment?
    owner? && %w[submitted verified].include?(record.status)
  end

  # Mini-CEX / DOPS dari kasus: aturan yang sama dengan CBD/Long Case.
  def initiate_workplace_assessment?
    initiate_assessment?
  end

  class Scope < Scope
    def resolve
      return scope.owned_by(user) unless user.can_verify_clinical_cases?

      user_ids = UserAssignment.active.where(user: user, assignment_role: "clinical_case_verifier").filter_map do |assignment|
        case assignment.scope_type
        when "User" then assignment.scope_id
        when "StudyProgram" then User.where(study_program_id: assignment.scope_id).pluck(:id)
        when "ClinicalRotation" then ClinicalRotation.where(id: assignment.scope_id).pluck(:user_id)
        else assignment.study_program_id && User.where(study_program_id: assignment.study_program_id).pluck(:id)
        end
      end.flatten.uniq
      rotation_cases = scope.joins(user: :clinical_rotations).where(clinical_rotations: { preceptor_id: user.id })
        .where("clinical_rotations.start_date <= clinical_cases.case_date AND clinical_rotations.end_date >= clinical_cases.case_date")
      scope.where(user_id: [user.id, *user_ids]).or(scope.where(supervisor_id: user.id))
        .or(scope.where(verified_by_id: user.id)).or(rotation_cases)
    end
  end

  private

  def owner?
    record.user_id == user.id
  end

  def assigned_verifier?
    return true if record.supervisor_id == user.id
    return false if record.supervisor_id.present?

    record.user.clinical_rotations.covering(record.case_date).exists?(preceptor: user) ||
      AssignmentAuthorization.assigned?(user: user, role: "clinical_case_verifier", student: record.user)
  end

  def assigned_supervisor?
    record.supervisor_id == user.id
  end
end
