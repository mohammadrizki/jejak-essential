# frozen_string_literal: true

class CreateStudentProgramEnrollmentsAndTransfers < ActiveRecord::Migration[8.1]
  class LegacyUser < ActiveRecord::Base
    self.table_name = "users"
    has_many :legacy_user_roles, class_name: "CreateStudentProgramEnrollmentsAndTransfers::LegacyUserRole", foreign_key: :user_id
  end

  class LegacyUserRole < ActiveRecord::Base
    self.table_name = "user_roles"
    belongs_to :role, class_name: "CreateStudentProgramEnrollmentsAndTransfers::LegacyRole"
  end

  class LegacyRole < ActiveRecord::Base
    self.table_name = "roles"
  end

  class Enrollment < ActiveRecord::Base
    self.table_name = "student_program_enrollments"
  end

  def up
    create_table :student_program_enrollments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :study_program, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :identifier_number
      t.integer :cohort_year
      t.string :status, null: false, default: "active"
      t.date :started_on, null: false
      t.date :completed_on
      t.text :status_reason
      t.jsonb :provenance, null: false, default: {}
      t.timestamps
    end

    add_check_constraint :student_program_enrollments,
      "status IN ('active', 'graduated', 'withdrawn', 'suspended')",
      name: "chk_student_program_enrollments_status"
    add_check_constraint :student_program_enrollments,
      "completed_on IS NULL OR completed_on >= started_on",
      name: "chk_student_program_enrollments_dates"
    add_check_constraint :student_program_enrollments,
      "status <> 'graduated' OR completed_on IS NOT NULL",
      name: "chk_student_program_enrollments_graduation_date"
    add_index :student_program_enrollments, :user_id, unique: true,
      where: "status = 'active'", name: "idx_one_active_student_program_enrollment"
    add_index :student_program_enrollments, %i[study_program_id identifier_number], unique: true,
      where: "identifier_number IS NOT NULL", name: "idx_student_program_enrollment_identifier"

    create_table :student_program_transfers do |t|
      t.references :student, null: false, foreign_key: { to_table: :users }
      t.references :source_enrollment, null: false, foreign_key: { to_table: :student_program_enrollments }
      t.references :destination_study_program, null: false, foreign_key: { to_table: :study_programs }
      t.references :destination_enrollment, foreign_key: { to_table: :student_program_enrollments }
      t.references :requested_by, null: false, foreign_key: { to_table: :users }
      t.references :decided_by, foreign_key: { to_table: :users }
      t.string :destination_identifier_number
      t.integer :destination_cohort_year
      t.string :status, null: false, default: "pending"
      t.text :decision_note
      t.datetime :decided_at
      t.timestamps
    end

    add_check_constraint :student_program_transfers,
      "status IN ('pending', 'accepted', 'rejected', 'cancelled')",
      name: "chk_student_program_transfers_status"
    add_check_constraint :student_program_transfers,
      "status <> 'accepted' OR destination_enrollment_id IS NOT NULL",
      name: "chk_student_program_transfers_accepted_enrollment"
    add_index :student_program_transfers, :source_enrollment_id, unique: true,
      where: "status = 'pending'", name: "idx_one_pending_transfer_per_enrollment"
    add_index :student_program_transfers, %i[destination_study_program_id status created_at],
      name: "idx_student_transfers_destination_status"

    backfill_legacy_enrollments
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "Transfer dan riwayat keanggotaan mahasiswa tidak boleh dihapus setelah digunakan."
  end

  private

  # Keep the legacy current-program pointer while creating its first historical
  # enrollment. The start date is explicitly marked as estimated when inferred
  # from cohort_year/account creation; no historical evidence is rewritten.
  def backfill_legacy_enrollments
    LegacyUser.joins(legacy_user_roles: :role).where(roles: { code: "mahasiswa" })
      .where.not(study_program_id: nil).distinct.find_each do |user|
      started_on = if user.cohort_year.present? && Date.valid_date?(user.cohort_year, 1, 1)
        Date.new(user.cohort_year, 1, 1)
      else
        user.created_at.to_date
      end
      Enrollment.create!(user_id: user.id, study_program_id: user.study_program_id,
        identifier_number: user.identifier_number, cohort_year: user.cohort_year,
        status: "active", started_on: started_on,
        provenance: { "source" => "legacy_backfill", "start_date_estimated" => true })
    end
  end
end
