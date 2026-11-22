# frozen_string_literal: true

class ExternalIdentityResolver
  def self.resolve_student!(source_system:, external_id:)
    mapping = ExternalIdentityMapping.find_by!(source_system: source_system, entity_type: "student",
      external_id: external_id.to_s)
    student = mapping.internal_record
    raise ActiveRecord::RecordNotFound, "Pemetaan tidak menunjuk ke akun mahasiswa JEJAK." unless
      student&.has_role?("mahasiswa")

    student
  end

  def self.map_student!(source_system:, external_id:, student:, by:, authority: "manual", revision: nil)
    raise ArgumentError, "Sistem sumber wajib dipilih." if source_system.to_s.blank?
    raise ArgumentError, "Identifier eksternal tidak boleh kosong." if external_id.to_s.blank?
    raise ArgumentError, "Target wajib merupakan akun mahasiswa." unless student&.has_role?("mahasiswa")
    authorized = by.has_role?("admin") ||
      (by.has_role?("kaprodi") && by.study_program_id == student.study_program_id) ||
      assigned_data_manager?(by, student)
    raise ArgumentError, "Pemberi pemetaan harus admin, Kaprodi, atau petugas data yang ditugaskan pada program mahasiswa." unless authorized

    ExternalIdentityMapping.create_or_find_by!(source_system: source_system.to_s, entity_type: "student",
      external_id: external_id.to_s) do |mapping|
      mapping.internal_record_type = "User"
      mapping.internal_record_id = student.id
      mapping.authority = authority
      mapping.source_revision = revision
      mapping.created_by = by
    end.tap do |mapping|
      if mapping.internal_record_id != student.id
        raise ArgumentError, "Identifier eksternal sudah dipetakan ke akun JEJAK lain; rekonsiliasi manual diperlukan."
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    raise ArgumentError, "Pemetaan identifier gagal: #{error.record.errors.full_messages.to_sentence}"
  end

  def self.assigned_data_manager?(user, student)
    AssignmentAuthorization.assigned?(user: user, role: "external_data_manager", student: student)
  end
end
