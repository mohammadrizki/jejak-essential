# frozen_string_literal: true

# Academic authority is scoped to the relevant program. Superadmin can manage
# permissions and inspect audit records, but is not implicitly an academic
# decision-maker for graduation or transfer acceptance.
class StudentTransferWorkflow
  class NotAuthorized < StandardError; end
  class InvalidTransition < StandardError; end

  # Academic decisions must come from an explicit role other than the system
  # superadmin grant. A user who separately holds a scoped Kaprodi role can
  # still act within that program's scope.
  def self.authorized_for?(user, permission, program)
    return false if user.blank? || program.blank?
    return false if user.study_program_bound? && user.study_program_id != program.id

    user.user_roles.includes(role: { role_permissions: :system_permission }).for_program(program).any? do |grant|
      next false if grant.role.code == "superadmin"

      grant.role.role_permissions.any? do |role_permission|
        next false unless role_permission.system_permission.key == permission.to_s
        next true if grant.scope_level == "study_program" && grant.study_program_id == program.id

        grant.scope_level == "system" && role_permission.scope_level == "system"
      end
    end
  end

  def graduate!(enrollment:, by:, completed_on: Date.current, reason: nil)
    authorize!(by, "students.graduate", enrollment.study_program)
    completed_on = Date.iso8601(completed_on.to_s) unless completed_on.is_a?(Date)
    reason = reason.to_s.strip.presence

    StudentProgramEnrollment.transaction do
      enrollment.lock!
      raise InvalidTransition, "Hanya keanggotaan prodi aktif yang dapat ditetapkan lulus." unless enrollment.active?
      raise InvalidTransition, "Akun mahasiswa tidak lagi menunjuk ke prodi ini." unless enrollment.user.study_program_id == enrollment.study_program_id
      raise InvalidTransition, "Tanggal lulus tidak boleh sebelum tanggal mulai." if completed_on < enrollment.started_on

      enrollment.update!(status: "graduated", completed_on: completed_on, status_reason: reason)
      audit!(by, enrollment.user, "student.enrollment.graduated", enrollment: enrollment,
        details: { study_program_id: enrollment.study_program_id, completed_on: completed_on.iso8601, reason: reason })
    end
    enrollment
  rescue Date::Error
    raise InvalidTransition, "Tanggal lulus tidak valid."
  end

  def request_transfer!(source_enrollment:, destination_study_program:, by:, destination_identifier_number: nil,
                        destination_cohort_year: nil)
    authorize!(by, "students.transfer.request", source_enrollment.study_program)
    StudentProgramTransfer.transaction do
      source_enrollment.lock!
      raise InvalidTransition, "Mahasiswa harus berstatus lulus di prodi asal sebelum diajukan transfer." unless source_enrollment.graduated?
      raise InvalidTransition, "Pilih program studi tujuan yang berbeda." if source_enrollment.study_program_id == destination_study_program.id
      raise InvalidTransition, "Riwayat kelulusan ini bukan keanggotaan terakhir mahasiswa." unless
        source_enrollment.user.study_program_id == source_enrollment.study_program_id
      raise InvalidTransition, "Mahasiswa sudah memiliki keanggotaan aktif di program studi lain." if
        source_enrollment.user.student_program_enrollments.active.exists?
      target_identifier = destination_identifier_number.presence || source_enrollment.user.identifier_number
      raise InvalidTransition, "NPM/NIM sudah digunakan di prodi tujuan." if target_identifier.present? &&
        StudentProgramEnrollment.exists?(study_program: destination_study_program, identifier_number: target_identifier)
      raise InvalidTransition, "Pengajuan transfer untuk riwayat kelulusan ini masih menunggu keputusan." if
        StudentProgramTransfer.pending.exists?(source_enrollment: source_enrollment)

      transfer = StudentProgramTransfer.create!(student: source_enrollment.user, source_enrollment: source_enrollment,
        destination_study_program: destination_study_program, requested_by: by,
        destination_identifier_number: destination_identifier_number.presence,
        destination_cohort_year: destination_cohort_year)
      audit!(by, transfer.student, "student.transfer.requested", transfer: transfer,
        details: { source_program_id: source_enrollment.study_program_id,
          destination_program_id: destination_study_program.id, transfer_id: transfer.id })
      transfer
    end
  rescue ActiveRecord::RecordNotUnique
    raise InvalidTransition, "Pengajuan transfer untuk mahasiswa ini sudah menunggu keputusan."
  end

  def accept!(transfer:, by:)
    authorize!(by, "students.transfer.accept", transfer.destination_study_program)
    StudentProgramTransfer.transaction do
      transfer.lock!
      raise InvalidTransition, "Pengajuan transfer sudah diputuskan." unless transfer.status == "pending"
      raise InvalidTransition, "Mahasiswa sudah memiliki keanggotaan aktif." if transfer.student.student_program_enrollments.active.exists?
      raise InvalidTransition, "Riwayat kelulusan tidak lagi menjadi prodi aktif mahasiswa." unless
        transfer.student.study_program_id == transfer.source_enrollment.study_program_id

      # Keep the old enrollment and all source evidence untouched. This legacy
      # pointer changes only after destination acceptance, for compatibility
      # with existing views and program-scoped queries.
      transfer.student.allow_student_program_transfer = true
      transfer.student.update!(study_program: transfer.destination_study_program,
        identifier_number: transfer.destination_identifier_number.presence || transfer.student.identifier_number,
        cohort_year: transfer.destination_cohort_year.presence || transfer.student.cohort_year)
      enrollment = StudentProgramEnrollment.create!(user: transfer.student,
        study_program: transfer.destination_study_program, created_by: by,
        identifier_number: transfer.destination_identifier_number.presence || transfer.student.identifier_number,
        cohort_year: transfer.destination_cohort_year.presence || transfer.student.cohort_year,
        status: "active", started_on: Date.current,
        provenance: { "source" => "accepted_transfer", "transfer_id" => transfer.id,
          "source_enrollment_id" => transfer.source_enrollment_id })
      transfer.update!(status: "accepted", destination_enrollment: enrollment, decided_by: by, decided_at: Time.current)
      audit!(by, transfer.student, "student.transfer.accepted", transfer: transfer,
        details: { transfer_id: transfer.id, source_enrollment_id: transfer.source_enrollment_id,
          destination_enrollment_id: enrollment.id, source_program_id: transfer.source_enrollment.study_program_id,
          destination_program_id: transfer.destination_study_program_id })
      transfer
    ensure
      transfer.student.allow_student_program_transfer = false
    end
  end

  def reject!(transfer:, by:, reason:)
    authorize!(by, "students.transfer.accept", transfer.destination_study_program)
    note = reason.to_s.strip
    raise InvalidTransition, "Alasan penolakan minimal 10 karakter." if note.length < 10

    StudentProgramTransfer.transaction do
      transfer.lock!
      raise InvalidTransition, "Pengajuan transfer sudah diputuskan." unless transfer.status == "pending"

      transfer.update!(status: "rejected", decided_by: by, decided_at: Time.current, decision_note: note)
      audit!(by, transfer.student, "student.transfer.rejected", transfer: transfer,
        details: { transfer_id: transfer.id, source_program_id: transfer.source_enrollment.study_program_id,
          destination_program_id: transfer.destination_study_program_id, reason: note })
      transfer
    end
  end

  private

  def authorize!(user, permission, program)
    return if self.class.authorized_for?(user, permission, program)

    raise NotAuthorized, "Permission #{permission} pada program studi ini diperlukan."
  end

  def audit!(actor, student, event_key, enrollment: nil, transfer: nil, details:)
    RbacAuditEvent.create!(actor_user: actor, subject_user: student, event_key: event_key,
      details: details.deep_stringify_keys.merge("enrollment_id" => enrollment&.id, "transfer_id" => transfer&.id).compact)
  end
end
