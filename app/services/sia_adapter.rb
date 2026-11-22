# frozen_string_literal: true

# SIA bridge resolves external IDs only. It does not create accounts, courses,
# schedules, attendance, or replace JEJAK's internal primary keys.
class SiaAdapter
  def initialize(study_program:)
    @study_program = study_program
  end

  def map_student!(external_id:, student:, by:, revision: nil)
    ensure_enabled!
    raise ArgumentError, "Mahasiswa berada di program studi lain." unless student.study_program_id == @study_program.id

    ExternalIdentityResolver.map_student!(source_system: "sia", external_id: external_id,
      student: student, by: by, authority: "integration", revision: revision)
  end

  def resolve_student!(external_id:)
    ensure_enabled!
    student = ExternalIdentityResolver.resolve_student!(source_system: "sia", external_id: external_id)
    raise ActiveRecord::RecordNotFound, "Mahasiswa tidak termasuk program studi ini." unless
      student.study_program_id == @study_program.id

    student
  end

  private

  def ensure_enabled!
    raise ArgumentError, "Adapter SIA belum diaktifkan untuk program studi ini." unless
      ModuleConfiguration.for(@study_program).enabled?("integration_sia")
  end
end
