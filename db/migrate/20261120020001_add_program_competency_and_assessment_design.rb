# frozen_string_literal: true

class AddProgramCompetencyAndAssessmentDesign < ActiveRecord::Migration[8.1]
  # Keep the entire migration atomic. Index creation is deliberately non-concurrent;
  # the narrowly scoped safety_assured wrapper below acknowledges the table lock.

  def up
    # Frameworks are versioned rows belonging to a study program. The previous
    # migration created a unique index on study_program_id; replace it with a
    # non-unique index before adding version-specific uniqueness.
    # This index replacement must remain in the same transaction as the new
    # versioned indexes below. PostgreSQL's concurrent index removal cannot
    # run in a transaction, so acknowledge the short lock explicitly.
    safety_assured do
      remove_index :competency_frameworks,
                   column: :study_program_id
    end
    safe_add_index :competency_frameworks, :study_program_id

    # Add nullable columns first, backfill existing rows, then enforce NOT NULL.
    add_column :competency_frameworks, :version, :string
    add_column :competency_frameworks, :education_stage, :string
    add_column :competency_frameworks, :effective_date, :date
    add_column :competency_frameworks, :status, :string

    safe_execute(<<~SQL)
      UPDATE competency_frameworks
      SET version = '1', status = 'published'
      WHERE version IS NULL OR status IS NULL
    SQL

    change_column_default :competency_frameworks, :version, from: nil, to: "1"
    change_column_default :competency_frameworks, :status, from: nil, to: "draft"

    safe_add_index :competency_frameworks, %i[study_program_id version],
              unique: true,
              name: "idx_framework_program_version"

    add_check_constraint :competency_frameworks,
                         "status IN ('draft', 'published', 'archived')",
                         name: "chk_framework_status",
                         validate: false
    add_check_constraint :competency_frameworks,
                         "education_stage IS NULL OR education_stage IN ('undergraduate', 'professional', 'specialist', 'subspecialist')",
                         name: "chk_framework_education_stage",
                         validate: false

    safe_execute(<<~SQL)
      UPDATE competency_frameworks
      SET education_stage = CASE study_programs.level
        WHEN 'sarjana' THEN 'undergraduate'
        WHEN 'profesi' THEN 'professional'
        WHEN 'spesialis' THEN 'specialist'
        WHEN 'subspesialis' THEN 'subspecialist'
      END
      FROM study_programs
      WHERE competency_frameworks.study_program_id = study_programs.id
        AND competency_frameworks.education_stage IS NULL
    SQL

    unmapped_frameworks = select_value(<<~SQL).to_i
      SELECT COUNT(*)
      FROM competency_frameworks
      WHERE education_stage IS NULL
    SQL
    if unmapped_frameworks.positive?
      raise ActiveRecord::MigrationError,
            "#{unmapped_frameworks} competency framework(s) could not be mapped to an education_stage. Check study_programs.level."
    end

    safe_validate_check_constraint :competency_frameworks, name: "chk_framework_status"
    safe_validate_check_constraint :competency_frameworks, name: "chk_framework_education_stage"

    add_check_constraint :competency_frameworks,
                         "version IS NOT NULL AND status IS NOT NULL AND education_stage IS NOT NULL",
                         name: "chk_framework_required_fields",
                         validate: false
    safe_validate_check_constraint :competency_frameworks, name: "chk_framework_required_fields"

    # The validated check above makes the NOT NULL metadata change safe on
    # PostgreSQL. Keep safety_assured narrowly scoped to this operation.
    safety_assured do
      change_column_null :competency_frameworks, :version, false
      change_column_null :competency_frameworks, :status, false
      change_column_null :competency_frameworks, :education_stage, false
    end

    safe_add_index :competency_frameworks, :study_program_id,
              unique: true,
              where: "status = 'published'",
              name: "idx_one_published_competency_framework"

    # Extend the existing two-level competency tree.
    add_column :competency_items, :code, :string
    add_column :competency_items, :level_type, :string
    safe_execute(<<~SQL)
      UPDATE competency_items
      SET level_type = CASE WHEN parent_id IS NULL THEN 'domain' ELSE 'competency' END
      WHERE level_type IS NULL
    SQL
    change_column_default :competency_items, :level_type, from: nil, to: "competency"

    add_check_constraint :competency_items,
                         "level_type IN ('domain', 'competency', 'subcompetency')",
                         name: "chk_competency_level_type",
                         validate: false
    add_check_constraint :competency_items,
                         "parent_id IS NULL OR parent_id <> id",
                         name: "chk_competency_not_self_parent",
                         validate: false
    add_check_constraint :competency_items,
                         "level_type IS NOT NULL",
                         name: "chk_competency_level_type_present",
                         validate: false
    safe_validate_check_constraint :competency_items, name: "chk_competency_level_type"
    safe_validate_check_constraint :competency_items, name: "chk_competency_not_self_parent"
    safe_validate_check_constraint :competency_items, name: "chk_competency_level_type_present"
    safety_assured do
      change_column_null :competency_items, :level_type, false
    end

    safe_add_index :competency_items, %i[competency_framework_id code],
              unique: true,
              where: "code IS NOT NULL",
              name: "idx_competency_items_framework_code"

    create_table :competency_indicators do |t|
      t.references :competency_item, null: false, foreign_key: true
      t.string :code
      t.text :description, null: false
      t.string :performance_level
      t.integer :position, null: false, default: 0
      t.boolean :is_active, null: false, default: true
      t.timestamps
    end
    safe_add_index :competency_indicators, %i[competency_item_id code],
              unique: true,
              where: "code IS NOT NULL",
              name: "idx_indicators_item_code"

    create_table :competency_progressions do |t|
      t.references :source_competency, null: false, foreign_key: { to_table: :competency_items }
      t.references :target_competency, null: false, foreign_key: { to_table: :competency_items }
      t.string :relationship_type, null: false
      t.text :notes
      t.timestamps
    end
    safe_add_index :competency_progressions,
              %i[source_competency_id target_competency_id relationship_type],
              unique: true,
              name: "idx_competency_progressions_unique"
    add_check_constraint :competency_progressions,
                         "source_competency_id <> target_competency_id",
                         name: "chk_progression_not_self"
    add_check_constraint :competency_progressions,
                         "relationship_type IN ('prerequisite', 'supports', 'develops_into')",
                         name: "chk_progression_relationship_type"

    create_table :blueprint_versions do |t|
      t.references :assessment_blueprint, null: false, foreign_key: true
      t.references :competency_framework, null: false, foreign_key: true
      t.integer :version, null: false
      t.string :status, null: false, default: "draft"
      t.date :effective_date
      t.text :change_notes
      t.timestamps
    end
    safe_add_index :blueprint_versions, %i[assessment_blueprint_id version],
              unique: true,
              name: "idx_blueprint_versions_unique"
    safe_add_index :blueprint_versions, :assessment_blueprint_id,
              unique: true,
              where: "status = 'published'",
              name: "idx_one_published_blueprint_version"
    add_check_constraint :blueprint_versions,
                         "status IN ('draft', 'published', 'archived')",
                         name: "chk_blueprint_version_status"

    create_table :assessment_methods do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.string :assessment_type
      t.boolean :is_active, null: false, default: true
      t.timestamps
    end
    safe_add_index :assessment_methods, :code,
              unique: true
    safe_execute(<<~SQL)
      INSERT INTO assessment_methods (code, name, assessment_type, is_active, created_at, updated_at) VALUES
        ('cbt', 'Computer-based test', 'written', TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('osce', 'OSCE', 'practical', TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('mini_cex', 'Mini-CEX', 'workplace', TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('dops', 'DOPS', 'workplace', TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('cbd', 'Case-based discussion', 'case', TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('portfolio', 'Portfolio review', 'portfolio', TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('reflection', 'Refleksi', 'reflection', TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL

    create_table :blueprint_items do |t|
      t.references :blueprint_version, null: false, foreign_key: true
      t.references :assessment_method, null: false, foreign_key: true
      t.string :code, null: false
      t.string :title, null: false
      t.text :assessment_context
      t.integer :target_count
      t.decimal :weight, precision: 7, scale: 3
      t.string :frequency
      t.string :curricular_stage
      t.string :minimum_standard
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    safe_add_index :blueprint_items, %i[blueprint_version_id code],
              unique: true,
              name: "idx_blueprint_items_version_code"

    # Add the nullable FK column to an existing table without automatically
    # creating a blocking index or immediately validating the FK.
    add_column :assessment_events, :blueprint_item_id, :bigint
    safe_add_index :assessment_events, :blueprint_item_id
    add_foreign_key :assessment_events, :blueprint_items,
                    column: :blueprint_item_id,
                    validate: false
    safe_validate_foreign_key :assessment_events, :blueprint_items,
                              column: :blueprint_item_id

    create_table :blueprint_item_competencies do |t|
      t.references :blueprint_item, null: false, foreign_key: true
      t.references :competency_item, null: false, foreign_key: true
      t.references :competency_indicator, foreign_key: true
      t.decimal :assessment_weight, precision: 7, scale: 3
      t.text :notes
      t.timestamps
    end
    safe_add_index :blueprint_item_competencies,
              %i[blueprint_item_id competency_item_id competency_indicator_id],
              unique: true,
              name: "idx_blueprint_item_competencies_unique"
    safe_add_index :blueprint_item_competencies,
              %i[blueprint_item_id competency_item_id],
              unique: true,
              where: "competency_indicator_id IS NULL",
              name: "idx_blueprint_item_competency_without_indicator"

    create_table :epas do |t|
      t.references :competency_framework, null: false, foreign_key: true
      t.string :code, null: false
      t.string :title, null: false
      t.text :description
      t.text :scope
      t.text :limitations
      t.string :risk_level
      t.string :status, null: false, default: "draft"
      t.timestamps
    end
    safe_add_index :epas, %i[competency_framework_id code],
              unique: true,
              name: "idx_epas_framework_code"
    add_check_constraint :epas,
                         "status IN ('draft', 'published', 'archived')",
                         name: "chk_epa_status"

    # Preserve legacy entrustment history while introducing an EPA target.
    add_column :entrustment_decisions, :epa_id, :bigint
    safe_add_index :entrustment_decisions, :epa_id
    add_foreign_key :entrustment_decisions, :epas,
                    column: :epa_id,
                    validate: false
    safe_validate_foreign_key :entrustment_decisions, :epas,
                              column: :epa_id
    change_column_null :entrustment_decisions, :competency_item_id, true
    safe_add_index :entrustment_decisions,
              %i[student_id epa_id superseded_at],
              name: "idx_entrustment_epa_history"

    safe_execute(<<~SQL)
      INSERT INTO epas (competency_framework_id, code, title, description, status, created_at, updated_at)
      SELECT f.id, 'LEGACY-' || ci.id::text, ci.title, ci.description, 'published', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM competency_items ci
      JOIN competency_frameworks f ON f.id = ci.competency_framework_id
      WHERE ci.parent_id IS NULL
    SQL
    safe_execute(<<~SQL)
      UPDATE entrustment_decisions ed
      SET epa_id = e.id
      FROM competency_items ci
      JOIN epas e ON e.competency_framework_id = ci.competency_framework_id
                 AND e.code = 'LEGACY-' || ci.id::text
      WHERE ed.competency_item_id = ci.id AND ci.parent_id IS NULL
    SQL

    create_table :epa_competencies do |t|
      t.references :epa, null: false, foreign_key: true
      t.references :competency_item, null: false, foreign_key: true
      t.references :competency_indicator, foreign_key: true
      t.string :contribution, null: false, default: "supporting"
      t.decimal :importance_weight, precision: 7, scale: 3
      t.text :notes
      t.timestamps
    end
    safe_add_index :epa_competencies,
              %i[epa_id competency_item_id competency_indicator_id],
              unique: true,
              name: "idx_epa_competencies_unique"
    safe_add_index :epa_competencies,
              %i[epa_id competency_item_id],
              unique: true,
              where: "competency_indicator_id IS NULL",
              name: "idx_epa_competency_without_indicator"
    safe_execute(<<~SQL)
      INSERT INTO epa_competencies (epa_id, competency_item_id, contribution, created_at, updated_at)
      SELECT e.id, ci.id, 'core', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM epas e
      JOIN competency_items ci ON e.code = 'LEGACY-' || ci.id::text
      WHERE ci.parent_id IS NULL
    SQL

    create_table :epa_milestones do |t|
      t.references :epa, null: false, foreign_key: true
      t.string :stage, null: false
      t.integer :expected_level, null: false
      t.date :effective_date
      t.text :notes
      t.timestamps
    end
    add_check_constraint :epa_milestones,
                         "expected_level BETWEEN 1 AND 5",
                         name: "chk_epa_milestone_level"

    create_table :blueprint_item_epas do |t|
      t.references :blueprint_item, null: false, foreign_key: true
      t.references :epa, null: false, foreign_key: true
      t.string :assessment_purpose, null: false
      t.integer :expected_level
      t.timestamps
    end
    safe_add_index :blueprint_item_epas,
              %i[blueprint_item_id epa_id assessment_purpose],
              unique: true,
              name: "idx_blueprint_item_epas_unique"
    add_check_constraint :blueprint_item_epas,
                         "assessment_purpose IN ('formative', 'summative', 'entrustment')",
                         name: "chk_blueprint_epa_purpose"
    add_check_constraint :blueprint_item_epas,
                         "expected_level IS NULL OR expected_level BETWEEN 1 AND 5",
                         name: "chk_blueprint_epa_expected_level"

    create_table :evidence_requirements do |t|
      t.references :competency_item, foreign_key: true
      t.references :competency_indicator, foreign_key: true
      t.references :epa, foreign_key: true
      t.references :blueprint_item, foreign_key: true
      t.references :assessment_method, foreign_key: true
      t.string :origin, null: false
      t.string :source_type, null: false
      t.integer :required_count, null: false, default: 1
      t.jsonb :fulfillment_rule, null: false, default: {}
      t.string :due_stage
      t.boolean :is_mandatory, null: false, default: true
      t.string :status, null: false, default: "active"
      t.timestamps
    end
    add_check_constraint :evidence_requirements,
                         "origin IN ('blueprint', 'manual')",
                         name: "chk_evidence_requirement_origin"
    add_check_constraint :evidence_requirements,
                         "source_type IN ('assessment', 'logbook', 'portfolio', 'reflection', 'other')",
                         name: "chk_evidence_requirement_source"
    add_check_constraint :evidence_requirements,
                         "status IN ('active', 'inactive')",
                         name: "chk_evidence_requirement_status"
    add_check_constraint :evidence_requirements,
                         "required_count > 0",
                         name: "chk_evidence_requirement_count"
    add_check_constraint :evidence_requirements,
                         "competency_item_id IS NOT NULL OR epa_id IS NOT NULL",
                         name: "chk_evidence_requirement_target"
    add_check_constraint :evidence_requirements,
                         "competency_indicator_id IS NULL OR competency_item_id IS NOT NULL",
                         name: "chk_evidence_indicator_target"
    add_check_constraint :evidence_requirements,
                         "(origin = 'blueprint' AND blueprint_item_id IS NOT NULL) OR (origin = 'manual' AND blueprint_item_id IS NULL)",
                         name: "chk_evidence_requirement_origin_source"

    safe_execute(<<~SQL)
      INSERT INTO evidence_requirements
        (competency_item_id, origin, source_type, required_count, fulfillment_rule, is_mandatory, status, created_at, updated_at)
      SELECT ci.id, 'manual', source.source_type, 1,
             jsonb_build_object('notes', COALESCE(ci.expected_evidence_text, '')),
             TRUE, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM competency_items ci
      CROSS JOIN LATERAL (
        SELECT DISTINCT CASE evidence_type
          WHEN 'observasi' THEN 'assessment'
          WHEN 'asesmen' THEN 'assessment'
          WHEN 'artefak' THEN 'portfolio'
          WHEN 'refleksi' THEN 'reflection'
          ELSE 'other'
        END AS source_type
        FROM jsonb_array_elements_text(ci.expected_evidence_types) AS item(evidence_type)
        UNION
        SELECT 'other' WHERE jsonb_array_length(ci.expected_evidence_types) = 0
      ) source
      WHERE COALESCE(ci.expected_evidence_text, '') <> '' OR jsonb_array_length(ci.expected_evidence_types) > 0
    SQL

    create_table :evidence_records do |t|
      t.references :evidence_requirement, null: false, foreign_key: true
      t.references :assessment_instance, foreign_key: true
      t.references :activity_log, foreign_key: true
      t.references :reflection_entry, foreign_key: true
      t.date :evidence_date, null: false
      t.string :result, null: false
      t.decimal :score, precision: 8, scale: 3
      t.text :feedback
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_check_constraint :evidence_records,
                         "result IN ('pass', 'fail', 'borderline', 'not_assessed', 'other')",
                         name: "chk_evidence_record_result"
    add_check_constraint :evidence_records,
                         "num_nonnulls(assessment_instance_id, activity_log_id, reflection_entry_id) = 1",
                         name: "chk_evidence_record_single_source"
    safe_add_index :evidence_records,
              %i[evidence_requirement_id evidence_date],
              name: "idx_evidence_records_requirement_date"
    safe_add_index :evidence_records,
              %i[evidence_requirement_id assessment_instance_id],
              unique: true,
              where: "assessment_instance_id IS NOT NULL",
              name: "idx_evidence_record_assessment_once"
    safe_add_index :evidence_records,
              %i[evidence_requirement_id activity_log_id],
              unique: true,
              where: "activity_log_id IS NOT NULL",
              name: "idx_evidence_record_activity_once"
    safe_add_index :evidence_records,
              %i[evidence_requirement_id reflection_entry_id],
              unique: true,
              where: "reflection_entry_id IS NOT NULL",
              name: "idx_evidence_record_reflection_once"

    create_table :competency_attainments do |t|
      t.references :student, null: false, foreign_key: { to_table: :users }
      t.references :competency_item, null: false, foreign_key: true
      t.integer :attainment_level
      t.datetime :decision_date, null: false
      t.references :decision_by, foreign_key: { to_table: :users }
      t.text :rationale
      t.string :status, null: false, default: "proposed"
      t.timestamps
    end
    add_check_constraint :competency_attainments,
                         "attainment_level IS NULL OR attainment_level BETWEEN 1 AND 5",
                         name: "chk_competency_attainment_level"
    add_check_constraint :competency_attainments,
                         "status IN ('proposed', 'approved', 'rejected')",
                         name: "chk_competency_attainment_status"
    safe_add_index :competency_attainments,
              %i[student_id competency_item_id decision_date],
              name: "idx_competency_attainments_history"

    # Capture each existing framework/blueprint pair as its first published
    # version. Legacy assessment_blueprint_mappings remain untouched.
    safe_execute(<<~SQL)
      INSERT INTO blueprint_versions (assessment_blueprint_id, competency_framework_id, version, status, created_at, updated_at)
      SELECT b.id, f.id, 1, 'published', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM assessment_blueprints b
      JOIN competency_frameworks f
        ON f.study_program_id = b.study_program_id
       AND f.status = 'published'
    SQL
  end

  def down
    if select_value("SELECT 1 FROM entrustment_decisions WHERE competency_item_id IS NULL LIMIT 1")
      raise ActiveRecord::IrreversibleMigration,
            "EPA-only entrustment decisions cannot be represented by the legacy schema"
    end

    drop_table :evidence_records
    drop_table :evidence_requirements
    drop_table :competency_attainments
    drop_table :blueprint_item_epas
    drop_table :epa_competencies
    drop_table :epa_milestones

    remove_index :entrustment_decisions,
                 name: "idx_entrustment_epa_history"
    remove_foreign_key :entrustment_decisions, column: :epa_id
    remove_index :entrustment_decisions, :epa_id
    remove_column :entrustment_decisions, :epa_id
    change_column_null :entrustment_decisions, :competency_item_id, false

    drop_table :epas
    drop_table :blueprint_item_competencies

    remove_foreign_key :assessment_events, column: :blueprint_item_id
    remove_index :assessment_events, :blueprint_item_id
    remove_column :assessment_events, :blueprint_item_id

    drop_table :blueprint_items
    drop_table :assessment_methods
    drop_table :blueprint_versions
    drop_table :competency_progressions
    drop_table :competency_indicators

    remove_index :competency_items,
                 name: "idx_competency_items_framework_code"
    remove_check_constraint :competency_items, name: "chk_competency_level_type_present"
    remove_check_constraint :competency_items, name: "chk_competency_not_self_parent"
    remove_check_constraint :competency_items, name: "chk_competency_level_type"
    remove_column :competency_items, :level_type
    remove_column :competency_items, :code

    remove_index :competency_frameworks,
                 name: "idx_one_published_competency_framework"
    remove_check_constraint :competency_frameworks, name: "chk_framework_required_fields"
    remove_check_constraint :competency_frameworks, name: "chk_framework_education_stage"
    remove_check_constraint :competency_frameworks, name: "chk_framework_status"
    remove_index :competency_frameworks,
                 name: "idx_framework_program_version"
    remove_index :competency_frameworks, :study_program_id
    remove_column :competency_frameworks, :status
    remove_column :competency_frameworks, :effective_date
    remove_column :competency_frameworks, :education_stage
    remove_column :competency_frameworks, :version
    safe_add_index :competency_frameworks, :study_program_id,
              unique: true
  end

  private

  # Non-concurrent CREATE INDEX is transactional in PostgreSQL. This migration
  # intentionally keeps all schema/data changes atomic; use this bypass only
  # because this migration is being run while the affected tables are small
  # or empty. Do not convert this to CONCURRENTLY: PostgreSQL forbids that
  # operation inside a transaction.
  def safe_add_index(*args, **options)
    safety_assured do
      add_index(*args, **options)
    end
  end

  # This migration uses reviewed, static SQL for backfills and data migration.
  # Keep these statements transactional while acknowledging that
  # strong_migrations cannot inspect their contents.
  def safe_execute(sql)
    safety_assured do
      execute(sql)
    end
  end

  def safe_validate_check_constraint(*args, **options)
    safety_assured do
      validate_check_constraint(*args, **options)
    end
  end

  def safe_validate_foreign_key(*args, **options)
    safety_assured do
      validate_foreign_key(*args, **options)
    end
  end

end
