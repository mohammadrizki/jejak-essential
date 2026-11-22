# frozen_string_literal: true

class ScopeAssessmentFormTemplatesToStudyPrograms < ActiveRecord::Migration[8.1]
  def up
    add_reference :assessment_form_templates, :study_program, index: false, foreign_key: false
    safety_assured do
      add_index :assessment_form_templates, :study_program_id
    end
    add_foreign_key :assessment_form_templates, :study_programs, validate: false

    safety_assured do
      execute <<~SQL
        UPDATE assessment_form_templates AS templates
        SET study_program_id = users.study_program_id
        FROM users
        WHERE templates.created_by_id = users.id
          AND users.study_program_id IS NOT NULL
          AND EXISTS (
            SELECT 1
            FROM user_roles
            INNER JOIN roles ON roles.id = user_roles.role_id
            WHERE user_roles.user_id = users.id AND roles.code = 'kaprodi'
          )
          AND NOT EXISTS (
            SELECT 1
            FROM user_roles
            INNER JOIN roles ON roles.id = user_roles.role_id
            WHERE user_roles.user_id = users.id AND roles.code = 'admin'
          )
      SQL
    end

    # The table contains configuration templates, not high-volume writes; the
    # FK validation stays inside this migration's PostgreSQL transaction.
    safety_assured do
      validate_foreign_key :assessment_form_templates, :study_programs
    end
  end

  def down
    remove_foreign_key :assessment_form_templates, :study_programs
    remove_reference :assessment_form_templates, :study_program, index: true
  end
end
