# frozen_string_literal: true

class CreatePortfolioCurationAndAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :artifact_submissions do |t|
      t.references :student, null: false, foreign_key: { to_table: :users }
      t.references :reviewer, foreign_key: { to_table: :users }
      t.string :source_type, null: false
      t.bigint :source_id, null: false
      t.text :selection_reason, null: false
      t.text :reflection
      t.string :status, null: false, default: "submitted"
      t.datetime :submitted_at, null: false
      t.datetime :reviewed_at
      t.text :review_notes
      t.timestamps
    end
    add_index :artifact_submissions, %i[student_id source_type source_id], unique: true,
      name: "idx_artifact_submission_source_once"
    add_index :artifact_submissions, %i[status submitted_at]
    add_check_constraint :artifact_submissions,
      "source_type IN ('ActivityLog', 'ReflectionEntry', 'EvidenceRecord')",
      name: "chk_artifact_submission_source_type"
    add_check_constraint :artifact_submissions,
      "status IN ('submitted', 'approved', 'rejected', 'withdrawn')",
      name: "chk_artifact_submission_status"

    create_table :portfolio_selections do |t|
      t.references :artifact_submission, null: false, foreign_key: true, index: { unique: true }
      t.references :student, null: false, foreign_key: { to_table: :users }
      t.string :visibility, null: false, default: "private"
      t.datetime :selected_at, null: false
      t.timestamps
    end
    add_check_constraint :portfolio_selections,
      "visibility IN ('private', 'assigned_reviewers')", name: "chk_portfolio_selection_visibility"

    create_table :user_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :assigned_by, null: false, foreign_key: { to_table: :users }
      t.references :study_program, foreign_key: true
      t.string :assignment_role, null: false
      t.string :scope_type
      t.bigint :scope_id
      t.date :starts_on
      t.date :ends_on
      t.datetime :revoked_at
      t.text :reason
      t.timestamps
    end
    add_index :user_assignments, %i[user_id assignment_role],
      name: "idx_user_assignments_scope"
    add_check_constraint :user_assignments,
      "ends_on IS NULL OR starts_on IS NULL OR ends_on >= starts_on",
      name: "chk_user_assignment_dates"

    create_table :wpba_instruments do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :instrument_type, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :wpba_instruments, :code, unique: true

    create_table :wpba_instrument_versions do |t|
      t.references :wpba_instrument, null: false, foreign_key: true
      t.string :version_label, null: false
      t.jsonb :definition, null: false, default: {}
      t.datetime :published_at
      t.references :published_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :wpba_instrument_versions, %i[wpba_instrument_id version_label], unique: true,
      name: "idx_wpba_instrument_versions_unique"
    # These nullable references are added with transactional indexes as
    # required by the project migration policy; no concurrent DDL is used.
    safety_assured do
      add_reference :mini_cex_evaluations, :wpba_instrument_version, foreign_key: { validate: false }
      add_reference :dops_evaluations, :wpba_instrument_version, foreign_key: { validate: false }
      add_reference :assessment_events, :wpba_instrument_version, foreign_key: { validate: false }
    end
    safety_assured do
      validate_foreign_key :mini_cex_evaluations, :wpba_instrument_versions
      validate_foreign_key :dops_evaluations, :wpba_instrument_versions
      validate_foreign_key :assessment_events, :wpba_instrument_versions
    end
  end
end
