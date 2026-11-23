# frozen_string_literal: true

# Creates the first durable program membership for newly configured student
# accounts. Existing history without an active enrollment is never reopened;
# those transitions must go through the transfer decision workflow.
class StudentProgramEnrollmentBootstrap
  def self.ensure_current!(user:, by: nil)
    return unless user.has_role?("mahasiswa") && user.study_program.present?

    active = user.student_program_enrollments.active.first
    return active if active
    # Graduated/withdrawn accounts keep their historic program pointer until a
    # transfer is accepted; never reopen them as active during routine edits.
    return if user.student_program_enrollments.exists?

    started_on = if user.cohort_year.present? && Date.valid_date?(user.cohort_year, 1, 1)
      Date.new(user.cohort_year, 1, 1)
    else
      Date.current
    end
    user.student_program_enrollments.create!(study_program: user.study_program, created_by: by,
      identifier_number: user.identifier_number, cohort_year: user.cohort_year, status: "active",
      started_on: started_on, provenance: { "source" => "account_setup" })
  end
end
