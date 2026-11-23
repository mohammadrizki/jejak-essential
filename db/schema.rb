# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_23_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "academic_activity_domains", force: :cascade do |t|
    t.string "color_code"
    t.datetime "created_at", null: false
    t.string "icon"
    t.boolean "is_active", default: true, null: false
    t.boolean "is_clinical", default: false, null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_academic_activity_domains_on_name", unique: true
  end

  create_table "academic_activity_subdomains", force: :cascade do |t|
    t.bigint "academic_activity_domain_id", null: false
    t.datetime "created_at", null: false
    t.boolean "is_active", default: true, null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["academic_activity_domain_id", "name"], name: "idx_activity_subdomains_unique_name", unique: true
    t.index ["academic_activity_domain_id"], name: "idx_on_academic_activity_domain_id_bf2d5d6c50"
  end

  create_table "academic_activity_templates", force: :cascade do |t|
    t.bigint "academic_activity_subdomain_id", null: false
    t.datetime "created_at", null: false
    t.boolean "is_active", default: true, null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["academic_activity_subdomain_id", "name"], name: "idx_activity_templates_unique_name", unique: true
    t.index ["academic_activity_subdomain_id"], name: "idx_on_academic_activity_subdomain_id_02a6c97b80"
  end

  create_table "academic_periods", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "end_date", null: false
    t.string "name", null: false
    t.date "start_date", null: false
    t.datetime "updated_at", null: false
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "activity_log_competency_tags", force: :cascade do |t|
    t.bigint "activity_log_id", null: false
    t.bigint "competency_item_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activity_log_id", "competency_item_id"], name: "index_activity_log_competency_tags_uniq", unique: true
    t.index ["activity_log_id"], name: "index_activity_log_competency_tags_on_activity_log_id"
    t.index ["competency_item_id"], name: "index_activity_log_competency_tags_on_competency_item_id"
  end

  create_table "activity_logs", force: :cascade do |t|
    t.bigint "academic_activity_domain_id"
    t.bigint "academic_activity_subdomain_id"
    t.bigint "academic_activity_template_id"
    t.bigint "academic_period_id"
    t.date "activity_date", null: false
    t.string "activity_type"
    t.string "category", null: false
    t.bigint "clinical_rotation_id"
    t.datetime "created_at", null: false
    t.string "delivery_mode"
    t.text "description"
    t.string "document_url"
    t.datetime "ended_at"
    t.string "evidence_url"
    t.string "location"
    t.integer "participant_count"
    t.string "patient_code"
    t.text "reflection"
    t.datetime "started_at"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.datetime "verified_at"
    t.bigint "verified_by_id"
    t.index ["academic_activity_domain_id"], name: "index_activity_logs_on_academic_activity_domain_id"
    t.index ["academic_activity_subdomain_id"], name: "index_activity_logs_on_academic_activity_subdomain_id"
    t.index ["academic_activity_template_id"], name: "index_activity_logs_on_academic_activity_template_id"
    t.index ["academic_period_id"], name: "index_activity_logs_on_academic_period_id"
    t.index ["category"], name: "index_activity_logs_on_category"
    t.index ["clinical_rotation_id"], name: "index_activity_logs_on_clinical_rotation_id"
    t.index ["user_id", "activity_date"], name: "index_activity_logs_on_user_id_and_activity_date"
    t.index ["user_id"], name: "index_activity_logs_on_user_id"
    t.index ["verified_by_id"], name: "index_activity_logs_on_verified_by_id"
  end

  create_table "app_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.bigint "updated_by_id"
    t.jsonb "value", default: {}, null: false
    t.index ["key"], name: "index_app_settings_on_key", unique: true
    t.index ["updated_by_id"], name: "index_app_settings_on_updated_by_id"
  end

  create_table "artifact_submission_reviews", force: :cascade do |t|
    t.bigint "artifact_submission_id", null: false
    t.bigint "reviewer_id", null: false
    t.string "decision", null: false
    t.text "notes", null: false
    t.datetime "reviewed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["artifact_submission_id", "reviewer_id", "reviewed_at"], name: "idx_artifact_submission_review_history"
    t.index ["artifact_submission_id"], name: "index_artifact_submission_reviews_on_artifact_submission_id"
    t.index ["reviewer_id"], name: "index_artifact_submission_reviews_on_reviewer_id"
    t.check_constraint "decision::text = ANY (ARRAY['approved'::character varying::text, 'rejected'::character varying::text])", name: "chk_artifact_submission_review_decision"
  end

  create_table "artifact_submissions", force: :cascade do |t|
    t.bigint "student_id", null: false
    t.bigint "reviewer_id"
    t.string "source_type", null: false
    t.bigint "source_id", null: false
    t.text "selection_reason", null: false
    t.text "reflection"
    t.string "status", default: "submitted", null: false
    t.datetime "submitted_at", null: false
    t.datetime "reviewed_at"
    t.text "review_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "source_provenance", default: {}, null: false
    t.index ["reviewer_id"], name: "index_artifact_submissions_on_reviewer_id"
    t.index ["status", "submitted_at"], name: "index_artifact_submissions_on_status_and_submitted_at"
    t.index ["student_id", "source_type", "source_id"], name: "idx_artifact_submission_source_once", unique: true
    t.index ["student_id"], name: "index_artifact_submissions_on_student_id"
    t.check_constraint "source_type::text = ANY (ARRAY['ActivityLog'::character varying::text, 'ReflectionEntry'::character varying::text, 'EvidenceRecord'::character varying::text])", name: "chk_artifact_submission_source_type"
    t.check_constraint "status::text = ANY (ARRAY['submitted'::character varying::text, 'approved'::character varying::text, 'rejected'::character varying::text, 'withdrawn'::character varying::text])", name: "chk_artifact_submission_status"
  end

  create_table "assessment_blueprint_mappings", force: :cascade do |t|
    t.bigint "assessment_blueprint_id", null: false
    t.bigint "competency_item_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "weight", precision: 5, scale: 2, null: false
    t.index ["assessment_blueprint_id", "competency_item_id"], name: "index_blueprint_mappings_uniq", unique: true
    t.index ["assessment_blueprint_id"], name: "index_assessment_blueprint_mappings_on_assessment_blueprint_id"
    t.index ["competency_item_id"], name: "index_assessment_blueprint_mappings_on_competency_item_id"
  end

  create_table "assessment_blueprints", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.jsonb "learning_outcomes", default: [], null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "study_program_id", null: false
    t.index ["study_program_id"], name: "index_assessment_blueprints_on_study_program_id", unique: true
  end

  create_table "assessment_dimension_scores", force: :cascade do |t|
    t.bigint "assessment_dimension_id", null: false
    t.bigint "assessment_instance_id", null: false
    t.datetime "created_at", null: false
    t.decimal "score", precision: 6, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["assessment_dimension_id"], name: "index_assessment_dimension_scores_on_assessment_dimension_id"
    t.index ["assessment_instance_id", "assessment_dimension_id"], name: "idx_dimension_scores_unique", unique: true
    t.index ["assessment_instance_id"], name: "index_assessment_dimension_scores_on_assessment_instance_id"
  end

  create_table "assessment_dimensions", force: :cascade do |t|
    t.bigint "assessment_event_id", null: false
    t.string "category"
    t.string "code"
    t.bigint "competency_item_id"
    t.datetime "created_at", null: false
    t.decimal "max_score", precision: 6, scale: 2, default: "100.0", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.decimal "weight", precision: 6, scale: 2, default: "1.0", null: false
    t.index ["assessment_event_id", "name"], name: "idx_assessment_dimensions_unique_name", unique: true
    t.index ["assessment_event_id"], name: "index_assessment_dimensions_on_assessment_event_id"
    t.index ["competency_item_id"], name: "index_assessment_dimensions_on_competency_item_id"
  end

  create_table "assessment_events", force: :cascade do |t|
    t.bigint "academic_period_id", null: false
    t.boolean "allow_multiple_attempts", default: false, null: false
    t.bigint "assessment_form_template_id"
    t.string "assessment_type", null: false
    t.string "block_name"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.text "description"
    t.date "exam_date"
    t.string "exam_purpose"
    t.string "external_code"
    t.decimal "max_score", precision: 6, scale: 2, default: "100.0", null: false
    t.string "name", null: false
    t.string "status", default: "draft", null: false
    t.bigint "study_program_id"
    t.datetime "submission_close_at"
    t.datetime "updated_at", null: false
    t.bigint "blueprint_item_id"
    t.bigint "wpba_instrument_version_id"
    t.index ["academic_period_id", "assessment_type"], name: "idx_on_academic_period_id_assessment_type_60ee6849bc"
    t.index ["academic_period_id"], name: "index_assessment_events_on_academic_period_id"
    t.index ["assessment_form_template_id"], name: "index_assessment_events_on_assessment_form_template_id"
    t.index ["blueprint_item_id"], name: "index_assessment_events_on_blueprint_item_id"
    t.index ["created_by_id"], name: "index_assessment_events_on_created_by_id"
    t.index ["external_code"], name: "index_assessment_events_on_external_code", unique: true, where: "(external_code IS NOT NULL)"
    t.index ["study_program_id"], name: "index_assessment_events_on_study_program_id"
    t.index ["wpba_instrument_version_id"], name: "index_assessment_events_on_wpba_instrument_version_id"
  end

  create_table "assessment_form_answers", force: :cascade do |t|
    t.bigint "assessment_form_field_id", null: false
    t.bigint "assessment_form_submission_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["assessment_form_field_id"], name: "index_assessment_form_answers_on_assessment_form_field_id"
    t.index ["assessment_form_submission_id"], name: "index_assessment_form_answers_on_assessment_form_submission_id"
  end

  create_table "assessment_form_fields", force: :cascade do |t|
    t.bigint "assessment_form_template_id", null: false
    t.bigint "competency_item_id"
    t.datetime "created_at", null: false
    t.string "field_type", null: false
    t.string "help_text"
    t.string "label", null: false
    t.integer "max_score", default: 5, null: false
    t.jsonb "options", default: [], null: false
    t.integer "position", default: 0, null: false
    t.boolean "required", default: true, null: false
    t.datetime "updated_at", null: false
    t.decimal "weight", precision: 6, scale: 2, default: "1.0", null: false
    t.index ["assessment_form_template_id"], name: "index_assessment_form_fields_on_assessment_form_template_id"
    t.index ["competency_item_id"], name: "index_assessment_form_fields_on_competency_item_id"
  end

  create_table "assessment_form_submissions", force: :cascade do |t|
    t.bigint "assessment_form_template_id", null: false
    t.datetime "created_at", null: false
    t.bigint "respondent_id", null: false
    t.string "subject_label"
    t.bigint "subject_user_id"
    t.datetime "submitted_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assessment_form_template_id"], name: "idx_on_assessment_form_template_id_27a2546b02"
    t.index ["respondent_id"], name: "index_assessment_form_submissions_on_respondent_id"
    t.index ["subject_user_id"], name: "index_assessment_form_submissions_on_subject_user_id"
  end

  create_table "assessment_form_templates", force: :cascade do |t|
    t.boolean "anonymous", default: false, null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.text "description"
    t.boolean "is_active", default: true, null: false
    t.string "name", null: false
    t.boolean "requires_subject_user", default: false, null: false
    t.datetime "updated_at", null: false
    t.bigint "study_program_id"
    t.index ["created_by_id"], name: "index_assessment_form_templates_on_created_by_id"
    t.index ["study_program_id"], name: "index_assessment_form_templates_on_study_program_id"
  end

  create_table "assessment_instances", force: :cascade do |t|
    t.bigint "assessment_event_id", null: false
    t.bigint "assessment_form_submission_id"
    t.integer "attempt_number", default: 1, null: false
    t.bigint "clinical_case_id"
    t.datetime "created_at", null: false
    t.bigint "examiner_id"
    t.text "feedback_improve"
    t.text "feedback_keep"
    t.decimal "max_score", precision: 6, scale: 2, default: "100.0", null: false
    t.datetime "scheduled_at"
    t.decimal "score", precision: 6, scale: 2
    t.datetime "scored_at"
    t.text "self_evaluation"
    t.string "source", default: "manual", null: false
    t.string "status", default: "registered", null: false
    t.bigint "student_id", null: false
    t.datetime "submitted_at"
    t.datetime "updated_at", null: false
    t.index ["assessment_event_id", "student_id", "attempt_number"], name: "idx_assessment_instances_unique_attempt", unique: true
    t.index ["assessment_event_id"], name: "index_assessment_instances_on_assessment_event_id"
    t.index ["assessment_form_submission_id"], name: "index_assessment_instances_on_assessment_form_submission_id"
    t.index ["clinical_case_id"], name: "index_assessment_instances_on_clinical_case_id"
    t.index ["examiner_id"], name: "index_assessment_instances_on_examiner_id"
    t.index ["student_id", "status"], name: "index_assessment_instances_on_student_id_and_status"
    t.index ["student_id"], name: "index_assessment_instances_on_student_id"
  end

  create_table "assessment_mappings", force: :cascade do |t|
    t.bigint "assessment_event_id", null: false
    t.datetime "created_at", null: false
    t.bigint "learning_unit_id", null: false
    t.datetime "updated_at", null: false
    t.decimal "weight", precision: 5, scale: 2, default: "0.0", null: false
    t.index ["assessment_event_id"], name: "index_assessment_mappings_on_assessment_event_id"
    t.index ["learning_unit_id", "assessment_event_id"], name: "idx_assessment_mappings_unique", unique: true
    t.index ["learning_unit_id"], name: "index_assessment_mappings_on_learning_unit_id"
  end

  create_table "assessment_methods", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.text "description"
    t.string "assessment_type"
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_assessment_methods_on_code", unique: true
  end

  create_table "blueprint_item_competencies", force: :cascade do |t|
    t.bigint "blueprint_item_id", null: false
    t.bigint "competency_item_id", null: false
    t.bigint "competency_indicator_id"
    t.decimal "assessment_weight", precision: 7, scale: 3
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["blueprint_item_id", "competency_item_id", "competency_indicator_id"], name: "idx_blueprint_item_competencies_unique", unique: true
    t.index ["blueprint_item_id", "competency_item_id"], name: "idx_blueprint_item_competency_without_indicator", unique: true, where: "(competency_indicator_id IS NULL)"
    t.index ["blueprint_item_id"], name: "index_blueprint_item_competencies_on_blueprint_item_id"
    t.index ["competency_indicator_id"], name: "index_blueprint_item_competencies_on_competency_indicator_id"
    t.index ["competency_item_id"], name: "index_blueprint_item_competencies_on_competency_item_id"
  end

  create_table "blueprint_item_epas", force: :cascade do |t|
    t.bigint "blueprint_item_id", null: false
    t.bigint "epa_id", null: false
    t.string "assessment_purpose", null: false
    t.integer "expected_level"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "supervision_level_id"
    t.index ["blueprint_item_id", "epa_id", "assessment_purpose"], name: "idx_blueprint_item_epas_unique", unique: true
    t.index ["blueprint_item_id"], name: "index_blueprint_item_epas_on_blueprint_item_id"
    t.index ["epa_id"], name: "index_blueprint_item_epas_on_epa_id"
    t.index ["supervision_level_id"], name: "index_blueprint_item_epas_on_supervision_level_id"
    t.check_constraint "assessment_purpose::text = ANY (ARRAY['formative'::character varying::text, 'summative'::character varying::text, 'entrustment'::character varying::text])", name: "chk_blueprint_epa_purpose"
    t.check_constraint "expected_level IS NULL OR expected_level >= 1", name: "chk_blueprint_epa_expected_level"
  end

  create_table "blueprint_items", force: :cascade do |t|
    t.bigint "blueprint_version_id", null: false
    t.bigint "assessment_method_id", null: false
    t.string "code", null: false
    t.string "title", null: false
    t.text "assessment_context"
    t.integer "target_count"
    t.decimal "weight", precision: 7, scale: 3
    t.string "frequency"
    t.string "curricular_stage"
    t.string "minimum_standard"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assessment_method_id"], name: "index_blueprint_items_on_assessment_method_id"
    t.index ["blueprint_version_id", "code"], name: "idx_blueprint_items_version_code", unique: true
    t.index ["blueprint_version_id"], name: "index_blueprint_items_on_blueprint_version_id"
  end

  create_table "blueprint_versions", force: :cascade do |t|
    t.bigint "assessment_blueprint_id", null: false
    t.bigint "competency_framework_id", null: false
    t.integer "version", null: false
    t.string "status", default: "draft", null: false
    t.date "effective_date"
    t.text "change_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assessment_blueprint_id", "version"], name: "idx_blueprint_versions_unique", unique: true
    t.index ["assessment_blueprint_id"], name: "idx_one_published_blueprint_version", unique: true, where: "((status)::text = 'published'::text)"
    t.index ["assessment_blueprint_id"], name: "index_blueprint_versions_on_assessment_blueprint_id"
    t.index ["competency_framework_id"], name: "index_blueprint_versions_on_competency_framework_id"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'published'::character varying::text, 'archived'::character varying::text])", name: "chk_blueprint_version_status"
  end

  create_table "break_glass_accesses", force: :cascade do |t|
    t.bigint "clinical_case_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "ip_address"
    t.text "reason", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["clinical_case_id"], name: "index_break_glass_accesses_on_clinical_case_id"
    t.index ["user_id", "clinical_case_id", "expires_at"], name: "idx_break_glass_active_lookup"
    t.index ["user_id"], name: "index_break_glass_accesses_on_user_id"
  end

  create_table "case_verification_comments", force: :cascade do |t|
    t.string "action", null: false
    t.text "body"
    t.bigint "clinical_case_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["clinical_case_id"], name: "index_case_verification_comments_on_clinical_case_id"
    t.index ["user_id"], name: "index_case_verification_comments_on_user_id"
  end

  create_table "clinical_cases", force: :cascade do |t|
    t.text "anamnesis"
    t.string "case_complexity"
    t.date "case_date", null: false
    t.string "chief_complaint", null: false
    t.string "clinical_setting"
    t.datetime "created_at", null: false
    t.text "diagnosis"
    t.string "entrustment_level"
    t.text "family_history"
    t.text "general_condition"
    t.string "icd10_code"
    t.text "laboratory_results"
    t.text "learning_points"
    t.text "management"
    t.text "other_investigations"
    t.text "patient_address"
    t.integer "patient_age"
    t.string "patient_age_group"
    t.text "patient_birth_date"
    t.string "patient_gender"
    t.text "patient_medical_record_number"
    t.text "patient_name"
    t.string "patient_occupation"
    t.text "patient_phone"
    t.text "physical_examination"
    t.text "radiology_results"
    t.boolean "recommend_remediation", default: false, null: false
    t.string "skdi_level"
    t.string "status", default: "draft", null: false
    t.bigint "supervisor_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.datetime "verified_at"
    t.bigint "verified_by_id"
    t.jsonb "vital_signs", default: {}, null: false
    t.index ["status"], name: "index_clinical_cases_on_status"
    t.index ["supervisor_id"], name: "index_clinical_cases_on_supervisor_id"
    t.index ["user_id", "status"], name: "index_clinical_cases_on_user_id_and_status"
    t.index ["user_id"], name: "index_clinical_cases_on_user_id"
    t.index ["verified_by_id"], name: "index_clinical_cases_on_verified_by_id"
  end

  create_table "clinical_rotations", force: :cascade do |t|
    t.bigint "academic_period_id", null: false
    t.datetime "created_at", null: false
    t.date "end_date", null: false
    t.string "institution_name"
    t.bigint "preceptor_id"
    t.date "start_date", null: false
    t.string "station_name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["academic_period_id"], name: "index_clinical_rotations_on_academic_period_id"
    t.index ["preceptor_id"], name: "index_clinical_rotations_on_preceptor_id"
    t.index ["user_id", "start_date"], name: "index_clinical_rotations_on_user_id_and_start_date"
    t.index ["user_id"], name: "index_clinical_rotations_on_user_id"
  end

  create_table "competency_attainment_reviews", force: :cascade do |t|
    t.bigint "competency_attainment_id", null: false
    t.bigint "reviewer_id", null: false
    t.string "decision", null: false
    t.text "notes", null: false
    t.datetime "reviewed_at", null: false
    t.datetime "created_at", null: false
    t.index ["competency_attainment_id"], name: "idx_on_competency_attainment_id_6813ec2ada"
    t.index ["reviewer_id"], name: "index_competency_attainment_reviews_on_reviewer_id"
    t.check_constraint "decision::text = ANY (ARRAY['approved'::character varying::text, 'rejected'::character varying::text])", name: "chk_competency_attainment_review_decision"
  end

  create_table "competency_attainments", force: :cascade do |t|
    t.bigint "student_id", null: false
    t.bigint "competency_item_id", null: false
    t.integer "attainment_level"
    t.datetime "decision_date", null: false
    t.bigint "decision_by_id"
    t.text "rationale"
    t.string "status", default: "proposed", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "framework_version"
    t.jsonb "evidence_snapshot", default: {}, null: false
    t.datetime "reviewed_at"
    t.text "review_notes"
    t.bigint "reviewed_by_id"
    t.index ["competency_item_id"], name: "index_competency_attainments_on_competency_item_id"
    t.index ["decision_by_id"], name: "index_competency_attainments_on_decision_by_id"
    t.index ["reviewed_by_id"], name: "index_competency_attainments_on_reviewed_by_id"
    t.index ["student_id", "competency_item_id", "decision_date"], name: "idx_competency_attainments_history"
    t.index ["student_id"], name: "index_competency_attainments_on_student_id"
    t.check_constraint "attainment_level IS NULL OR attainment_level >= 1 AND attainment_level <= 5", name: "chk_competency_attainment_level"
    t.check_constraint "status::text = ANY (ARRAY['proposed'::character varying::text, 'approved'::character varying::text, 'rejected'::character varying::text])", name: "chk_competency_attainment_status"
  end

  create_table "competency_frameworks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "study_program_id", null: false
    t.string "version", default: "1", null: false
    t.string "education_stage", null: false
    t.date "effective_date"
    t.string "status", default: "draft", null: false
    t.jsonb "provenance", default: {}, null: false
    t.index ["study_program_id", "version"], name: "idx_framework_program_version", unique: true
    t.index ["study_program_id"], name: "idx_one_published_competency_framework", unique: true, where: "((status)::text = 'published'::text)"
    t.index ["study_program_id"], name: "index_competency_frameworks_on_study_program_id"
    t.check_constraint "education_stage IS NULL OR (education_stage::text = ANY (ARRAY['sarjana'::character varying::text, 'profesi'::character varying::text, 'spesialis'::character varying::text, 'subspesialis'::character varying::text]))", name: "chk_framework_education_stage"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'published'::character varying::text, 'archived'::character varying::text])", name: "chk_framework_status"
    t.check_constraint "version IS NOT NULL AND status IS NOT NULL AND education_stage IS NOT NULL", name: "chk_framework_required_fields"
  end

  create_table "competency_indicators", force: :cascade do |t|
    t.bigint "competency_item_id", null: false
    t.string "code", null: false
    t.text "description", null: false
    t.string "performance_level"
    t.integer "position", default: 0, null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["competency_item_id", "code"], name: "idx_indicators_item_code", unique: true, where: "(code IS NOT NULL)"
    t.index ["competency_item_id"], name: "index_competency_indicators_on_competency_item_id"
  end

  create_table "competency_items", force: :cascade do |t|
    t.bigint "competency_framework_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "parent_id"
    t.integer "position", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.text "expected_evidence_text"
    t.jsonb "expected_evidence_types", default: [], null: false
    t.string "code", null: false
    t.string "level_type", default: "competency", null: false
    t.index ["competency_framework_id", "code"], name: "idx_competency_items_framework_code", unique: true, where: "(code IS NOT NULL)"
    t.index ["competency_framework_id"], name: "index_competency_items_on_competency_framework_id"
    t.index ["parent_id"], name: "index_competency_items_on_parent_id"
    t.check_constraint "level_type IS NOT NULL", name: "chk_competency_level_type_present"
    t.check_constraint "level_type::text = ANY (ARRAY['domain'::character varying::text, 'competency'::character varying::text, 'subcompetency'::character varying::text])", name: "chk_competency_level_type"
    t.check_constraint "parent_id IS NULL OR parent_id <> id", name: "chk_competency_not_self_parent"
  end

  create_table "competency_milestones", force: :cascade do |t|
    t.bigint "academic_period_id", null: false
    t.bigint "competency_item_id", null: false
    t.datetime "created_at", null: false
    t.integer "expected_score", null: false
    t.datetime "updated_at", null: false
    t.index ["academic_period_id"], name: "index_competency_milestones_on_academic_period_id"
    t.index ["competency_item_id", "academic_period_id"], name: "index_competency_milestones_uniq", unique: true
    t.index ["competency_item_id"], name: "index_competency_milestones_on_competency_item_id"
  end

  create_table "competency_progressions", force: :cascade do |t|
    t.bigint "source_competency_id", null: false
    t.bigint "target_competency_id", null: false
    t.string "relationship_type", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_competency_id", "target_competency_id", "relationship_type"], name: "idx_competency_progressions_unique", unique: true
    t.index ["source_competency_id"], name: "index_competency_progressions_on_source_competency_id"
    t.index ["target_competency_id"], name: "index_competency_progressions_on_target_competency_id"
    t.check_constraint "relationship_type::text = ANY (ARRAY['prerequisite'::character varying::text, 'supports'::character varying::text, 'develops_into'::character varying::text])", name: "chk_progression_relationship_type"
    t.check_constraint "source_competency_id <> target_competency_id", name: "chk_progression_not_self"
  end

  create_table "data_export_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "dataset", null: false
    t.jsonb "filters", default: {}, null: false
    t.integer "row_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["created_at"], name: "index_data_export_logs_on_created_at"
    t.index ["user_id"], name: "index_data_export_logs_on_user_id"
  end

  create_table "device_push_tokens", force: :cascade do |t|
    t.string "auth_key", null: false
    t.datetime "created_at", null: false
    t.string "endpoint", null: false
    t.string "p256dh_key", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["endpoint"], name: "index_device_push_tokens_on_endpoint", unique: true
    t.index ["user_id"], name: "index_device_push_tokens_on_user_id"
  end

  create_table "diagnosis_definitions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "icd10_code"
    t.string "name", null: false
    t.string "skdi_level"
    t.string "system_group"
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "idx_diagnosis_definitions_lower_name", unique: true
    t.index ["icd10_code"], name: "index_diagnosis_definitions_on_icd10_code"
  end

  create_table "dops_evaluations", force: :cascade do |t|
    t.string "case_complexity"
    t.bigint "clinical_case_id"
    t.bigint "clinical_rotation_id", null: false
    t.string "clinical_setting"
    t.datetime "created_at", null: false
    t.date "evaluated_at", null: false
    t.bigint "evaluator_id", null: false
    t.integer "feedback_minutes"
    t.integer "observation_minutes"
    t.text "overall_feedback"
    t.string "patient_age_group"
    t.string "procedure_name", null: false
    t.jsonb "scores", default: {}, null: false
    t.string "status", default: "submitted", null: false
    t.bigint "student_id", null: false
    t.datetime "updated_at", null: false
    t.string "video_recording_url"
    t.bigint "wpba_instrument_version_id"
    t.text "correction_reason"
    t.bigint "corrects_id"
    t.index ["clinical_case_id"], name: "index_dops_evaluations_on_clinical_case_id"
    t.index ["clinical_rotation_id"], name: "index_dops_evaluations_on_clinical_rotation_id"
    t.index ["corrects_id"], name: "index_dops_evaluations_on_corrects_id", unique: true
    t.index ["evaluator_id"], name: "index_dops_evaluations_on_evaluator_id"
    t.index ["student_id", "evaluated_at"], name: "index_dops_evaluations_on_student_id_and_evaluated_at"
    t.index ["student_id"], name: "index_dops_evaluations_on_student_id"
    t.index ["wpba_instrument_version_id"], name: "index_dops_evaluations_on_wpba_instrument_version_id"
  end

  create_table "entrustment_decision_events", force: :cascade do |t|
    t.bigint "entrustment_decision_id", null: false
    t.bigint "actor_id"
    t.string "event_type", null: false
    t.text "reason"
    t.jsonb "before_state", default: {}, null: false
    t.jsonb "after_state", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_entrustment_decision_events_on_actor_id"
    t.index ["entrustment_decision_id", "occurred_at"], name: "idx_entrustment_decision_events_history"
    t.index ["entrustment_decision_id"], name: "index_entrustment_decision_events_on_entrustment_decision_id"
    t.check_constraint "event_type::text = ANY (ARRAY['issued'::character varying::text, 'restricted'::character varying::text, 'renewed'::character varying::text, 'revoked'::character varying::text, 'expired'::character varying::text, 'corrected'::character varying::text, 'superseded'::character varying::text])", name: "chk_entrustment_decision_event_type"
  end

  create_table "entrustment_decisions", force: :cascade do |t|
    t.bigint "clinical_case_id"
    t.bigint "competency_item_id"
    t.datetime "created_at", null: false
    t.bigint "decided_by_id", null: false
    t.text "justification", null: false
    t.integer "level", null: false
    t.bigint "student_id", null: false
    t.datetime "superseded_at"
    t.bigint "superseded_by_id"
    t.datetime "updated_at", null: false
    t.bigint "epa_id"
    t.bigint "supervision_level_id"
    t.bigint "epa_promotion_id"
    t.datetime "review_due_at"
    t.datetime "review_due_notified_at"
    t.string "decision_kind", default: "legacy", null: false
    t.string "decision_status", default: "active", null: false
    t.text "activity_description"
    t.text "scope_limitations"
    t.jsonb "context", default: {}, null: false
    t.datetime "valid_from", null: false
    t.datetime "valid_until"
    t.datetime "revoked_at"
    t.bigint "revoked_by_id"
    t.text "revocation_reason"
    t.bigint "revocation_epa_promotion_id"
    t.index ["clinical_case_id"], name: "index_entrustment_decisions_on_clinical_case_id"
    t.index ["competency_item_id"], name: "index_entrustment_decisions_on_competency_item_id"
    t.index ["decided_by_id"], name: "index_entrustment_decisions_on_decided_by_id"
    t.index ["epa_id"], name: "index_entrustment_decisions_on_epa_id"
    t.index ["epa_promotion_id"], name: "index_entrustment_decisions_on_epa_promotion_id"
    t.index ["revocation_epa_promotion_id"], name: "index_entrustment_decisions_on_revocation_epa_promotion_id"
    t.index ["revoked_by_id"], name: "index_entrustment_decisions_on_revoked_by_id"
    t.index ["student_id", "competency_item_id", "superseded_at"], name: "idx_entrustment_current_lookup"
    t.index ["student_id", "epa_id", "decision_status"], name: "idx_entrustment_decision_lifecycle"
    t.index ["student_id", "epa_id", "superseded_at"], name: "idx_entrustment_epa_history"
    t.index ["student_id"], name: "index_entrustment_decisions_on_student_id"
    t.index ["superseded_by_id"], name: "index_entrustment_decisions_on_superseded_by_id"
    t.index ["supervision_level_id"], name: "index_entrustment_decisions_on_supervision_level_id"
    t.check_constraint "decision_kind::text = ANY (ARRAY['legacy'::character varying::text, 'ad_hoc'::character varying::text, 'summative'::character varying::text])", name: "chk_entrustment_decision_kind"
    t.check_constraint "decision_status::text = 'revoked'::text AND revoked_at IS NOT NULL AND revoked_by_id IS NOT NULL AND length(btrim(COALESCE(revocation_reason, ''::text))) >= 10 OR decision_status::text <> 'revoked'::text OR decision_kind::text = 'legacy'::text", name: "chk_entrustment_revocation_audit"
    t.check_constraint "decision_status::text = ANY (ARRAY['active'::character varying::text, 'restricted'::character varying::text, 'expired'::character varying::text, 'revoked'::character varying::text, 'superseded'::character varying::text])", name: "chk_entrustment_decision_status"
    t.check_constraint "valid_until IS NULL OR valid_until > valid_from", name: "chk_entrustment_validity_window"
  end

  create_table "epa_competencies", force: :cascade do |t|
    t.bigint "epa_id", null: false
    t.bigint "competency_item_id", null: false
    t.bigint "competency_indicator_id"
    t.string "contribution", default: "supporting", null: false
    t.decimal "importance_weight", precision: 7, scale: 3
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "ksa_dimension"
    t.boolean "is_prerequisite", default: false, null: false
    t.integer "minimum_attainment_level"
    t.boolean "is_critical", default: false, null: false
    t.index ["competency_indicator_id"], name: "index_epa_competencies_on_competency_indicator_id"
    t.index ["competency_item_id"], name: "index_epa_competencies_on_competency_item_id"
    t.index ["epa_id", "competency_item_id", "competency_indicator_id"], name: "idx_epa_competencies_unique", unique: true
    t.index ["epa_id", "competency_item_id"], name: "idx_epa_competency_without_indicator", unique: true, where: "(competency_indicator_id IS NULL)"
    t.index ["epa_id"], name: "index_epa_competencies_on_epa_id"
    t.check_constraint "ksa_dimension IS NULL OR (ksa_dimension::text = ANY (ARRAY['knowledge'::character varying::text, 'skill'::character varying::text, 'attitude'::character varying::text]))", name: "chk_epa_competency_ksa"
    t.check_constraint "minimum_attainment_level IS NULL OR minimum_attainment_level >= 1 AND minimum_attainment_level <= 5", name: "chk_epa_competency_minimum_level"
  end

  create_table "epa_milestones", force: :cascade do |t|
    t.bigint "epa_id", null: false
    t.string "stage", null: false
    t.integer "expected_level", null: false
    t.date "effective_date"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "supervision_level_id"
    t.index ["epa_id"], name: "index_epa_milestones_on_epa_id"
    t.index ["supervision_level_id"], name: "index_epa_milestones_on_supervision_level_id"
    t.check_constraint "expected_level >= 1", name: "chk_epa_milestone_level"
    t.check_constraint "stage::text = ANY (ARRAY['sarjana'::character varying::text, 'profesi'::character varying::text, 'spesialis'::character varying::text, 'subspesialis'::character varying::text])", name: "chk_epa_milestone_stage"
  end

  create_table "epa_observations", force: :cascade do |t|
    t.bigint "student_id", null: false
    t.bigint "epa_id", null: false
    t.bigint "observer_id", null: false
    t.bigint "clinical_case_id"
    t.bigint "clinical_rotation_id"
    t.bigint "supervision_level_id", null: false
    t.datetime "observed_at", null: false
    t.string "complexity", default: "routine", null: false
    t.text "activity_scope"
    t.text "narrative", null: false
    t.text "strengths"
    t.text "areas_to_improve"
    t.boolean "safety_flag", default: false, null: false
    t.string "status", default: "submitted", null: false
    t.datetime "submitted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "safety_resolution"
    t.datetime "safety_resolved_at"
    t.bigint "safety_resolved_by_id"
    t.index ["clinical_case_id"], name: "index_epa_observations_on_clinical_case_id"
    t.index ["clinical_rotation_id"], name: "index_epa_observations_on_clinical_rotation_id"
    t.index ["epa_id"], name: "index_epa_observations_on_epa_id"
    t.index ["observer_id", "status"], name: "index_epa_observations_on_observer_id_and_status"
    t.index ["observer_id"], name: "index_epa_observations_on_observer_id"
    t.index ["safety_resolved_by_id"], name: "index_epa_observations_on_safety_resolved_by_id"
    t.index ["student_id", "epa_id", "observed_at"], name: "idx_epa_observations_student_epa_date"
    t.index ["student_id"], name: "index_epa_observations_on_student_id"
    t.index ["supervision_level_id"], name: "index_epa_observations_on_supervision_level_id"
    t.check_constraint "complexity::text = ANY (ARRAY['routine'::character varying::text, 'moderate'::character varying::text, 'complex'::character varying::text, 'critical'::character varying::text])", name: "chk_epa_observation_complexity"
    t.check_constraint "safety_resolved_at IS NULL AND safety_resolved_by_id IS NULL AND safety_resolution IS NULL OR safety_resolved_at IS NOT NULL AND safety_resolved_by_id IS NOT NULL AND length(btrim(safety_resolution)) >= 10", name: "chk_epa_safety_resolution"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'submitted'::character varying::text, 'recorded'::character varying::text, 'returned'::character varying::text, 'voided'::character varying::text])", name: "chk_epa_observation_status"
  end

  create_table "epa_promotion_appeals", force: :cascade do |t|
    t.bigint "epa_promotion_id", null: false
    t.bigint "appealed_by_id", null: false
    t.bigint "resolved_by_id"
    t.integer "round_number", null: false
    t.text "reason", null: false
    t.string "resolution"
    t.text "resolution_notes"
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["appealed_by_id"], name: "index_epa_promotion_appeals_on_appealed_by_id"
    t.index ["epa_promotion_id", "round_number"], name: "idx_epa_promotion_appeals_round", unique: true
    t.index ["epa_promotion_id"], name: "index_epa_promotion_appeals_on_epa_promotion_id"
    t.index ["resolved_by_id"], name: "index_epa_promotion_appeals_on_resolved_by_id"
    t.check_constraint "resolution IS NULL OR (resolution::text = ANY (ARRAY['approved'::character varying::text, 'restricted'::character varying::text, 'needs_more_evidence'::character varying::text, 'not_entrusted'::character varying::text, 'deferred'::character varying::text, 'revoked'::character varying::text]))", name: "chk_epa_promotion_appeal_resolution"
  end

  create_table "epa_promotion_review_events", force: :cascade do |t|
    t.bigint "epa_promotion_review_id", null: false
    t.string "recommendation"
    t.bigint "supervision_level_id"
    t.text "notes", null: false
    t.datetime "recorded_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "event_kind", default: "recommendation", null: false
    t.boolean "conflict_disclosed", default: false, null: false
    t.index ["epa_promotion_review_id"], name: "index_epa_promotion_review_events_on_epa_promotion_review_id"
    t.index ["supervision_level_id"], name: "index_epa_promotion_review_events_on_supervision_level_id"
    t.check_constraint "event_kind::text = ANY (ARRAY['recommendation'::character varying::text, 'recusal'::character varying::text])", name: "chk_epa_panel_event_kind"
    t.check_constraint "recommendation::text = ANY (ARRAY['approved'::character varying::text, 'restricted'::character varying::text, 'needs_more_evidence'::character varying::text, 'not_entrusted'::character varying::text, 'deferred'::character varying::text, 'revoked'::character varying::text])", name: "chk_epa_panel_event_recommendation"
  end

  create_table "epa_promotion_reviews", force: :cascade do |t|
    t.bigint "epa_promotion_id", null: false
    t.bigint "reviewer_id", null: false
    t.bigint "supervision_level_id"
    t.string "recommendation", null: false
    t.text "notes", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "conflict_disclosed", default: false, null: false
    t.datetime "recused_at"
    t.text "recusal_reason"
    t.integer "round_number", default: 1, null: false
    t.index ["epa_promotion_id", "reviewer_id", "round_number"], name: "idx_epa_promotion_review_round_member", unique: true
    t.index ["epa_promotion_id"], name: "index_epa_promotion_reviews_on_epa_promotion_id"
    t.index ["reviewer_id"], name: "index_epa_promotion_reviews_on_reviewer_id"
    t.index ["supervision_level_id"], name: "index_epa_promotion_reviews_on_supervision_level_id"
    t.check_constraint "recommendation::text = ANY (ARRAY['approved'::character varying::text, 'restricted'::character varying::text, 'needs_more_evidence'::character varying::text, 'not_entrusted'::character varying::text, 'deferred'::character varying::text, 'revoked'::character varying::text])", name: "chk_epa_promotion_review_recommendation"
  end

  create_table "epa_promotions", force: :cascade do |t|
    t.bigint "student_id", null: false
    t.bigint "epa_id", null: false
    t.bigint "promoted_by_id"
    t.bigint "reviewed_by_id"
    t.string "status", default: "ready", null: false
    t.datetime "eligible_at", null: false
    t.datetime "promoted_at"
    t.datetime "reviewed_at"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "quorum_reached_at"
    t.jsonb "dossier_snapshot", default: {}, null: false
    t.bigint "finalized_by_id"
    t.datetime "finalized_at"
    t.datetime "appealed_at"
    t.text "appeal_reason"
    t.datetime "review_due_at"
    t.integer "review_round", default: 1, null: false
    t.bigint "renewal_of_decision_id"
    t.index ["epa_id"], name: "index_epa_promotions_on_epa_id"
    t.index ["promoted_by_id"], name: "index_epa_promotions_on_promoted_by_id"
    t.index ["renewal_of_decision_id"], name: "idx_epa_promotions_renewal_decision"
    t.index ["reviewed_by_id"], name: "index_epa_promotions_on_reviewed_by_id"
    t.index ["status", "eligible_at"], name: "index_epa_promotions_on_status_and_eligible_at"
    t.index ["student_id", "epa_id"], name: "idx_epa_promotions_open_student_epa", unique: true, where: "((status)::text = ANY (ARRAY[('ready'::character varying)::text, ('promoted'::character varying)::text, ('under_review'::character varying)::text, ('appeal_pending'::character varying)::text]))"
    t.index ["student_id"], name: "index_epa_promotions_on_student_id"
    t.check_constraint "status::text = ANY (ARRAY['ready'::character varying::text, 'promoted'::character varying::text, 'under_review'::character varying::text, 'needs_more_evidence'::character varying::text, 'not_entrusted'::character varying::text, 'approved'::character varying::text, 'restricted'::character varying::text, 'deferred'::character varying::text, 'revoked'::character varying::text, 'appeal_pending'::character varying::text])", name: "chk_epa_promotion_status"
  end

  create_table "epas", force: :cascade do |t|
    t.bigint "competency_framework_id", null: false
    t.string "code", null: false
    t.string "title", null: false
    t.text "description"
    t.text "scope"
    t.text "limitations"
    t.string "risk_level"
    t.string "status", default: "draft", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["competency_framework_id", "code"], name: "idx_epas_framework_code", unique: true
    t.index ["competency_framework_id"], name: "index_epas_on_competency_framework_id"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'published'::character varying::text, 'archived'::character varying::text])", name: "chk_epa_status"
  end

  create_table "evaluation_schedules", force: :cascade do |t|
    t.bigint "clinical_rotation_id"
    t.datetime "created_at", null: false
    t.bigint "evaluator_id"
    t.string "kind", null: false
    t.text "notes"
    t.datetime "scheduled_at", null: false
    t.string "status", default: "planned", null: false
    t.bigint "student_id", null: false
    t.string "topic"
    t.datetime "updated_at", null: false
    t.index ["clinical_rotation_id"], name: "index_evaluation_schedules_on_clinical_rotation_id"
    t.index ["evaluator_id", "status"], name: "index_evaluation_schedules_on_evaluator_id_and_status"
    t.index ["evaluator_id"], name: "index_evaluation_schedules_on_evaluator_id"
    t.index ["student_id", "scheduled_at"], name: "index_evaluation_schedules_on_student_id_and_scheduled_at"
    t.index ["student_id"], name: "index_evaluation_schedules_on_student_id"
  end

  create_table "evidence_records", force: :cascade do |t|
    t.bigint "evidence_requirement_id", null: false
    t.bigint "assessment_instance_id"
    t.bigint "activity_log_id"
    t.bigint "reflection_entry_id"
    t.date "evidence_date", null: false
    t.string "result", null: false
    t.decimal "score", precision: 8, scale: 3
    t.text "feedback"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "epa_observation_id"
    t.bigint "mini_cex_evaluation_id"
    t.bigint "dops_evaluation_id"
    t.bigint "evidence_source_id"
    t.bigint "evidence_requirement_version_id", null: false
    t.bigint "wpba_observation_id"
    t.index ["activity_log_id"], name: "index_evidence_records_on_activity_log_id"
    t.index ["assessment_instance_id"], name: "index_evidence_records_on_assessment_instance_id"
    t.index ["dops_evaluation_id"], name: "index_evidence_records_on_dops_evaluation_id"
    t.index ["epa_observation_id"], name: "index_evidence_records_on_epa_observation_id"
    t.index ["evidence_requirement_id", "activity_log_id"], name: "idx_evidence_record_activity_once", unique: true, where: "(activity_log_id IS NOT NULL)"
    t.index ["evidence_requirement_id", "assessment_instance_id"], name: "idx_evidence_record_assessment_once", unique: true, where: "(assessment_instance_id IS NOT NULL)"
    t.index ["evidence_requirement_id", "dops_evaluation_id"], name: "idx_evidence_record_dops_once", unique: true, where: "(dops_evaluation_id IS NOT NULL)"
    t.index ["evidence_requirement_id", "epa_observation_id"], name: "idx_evidence_record_epa_observation_once", unique: true, where: "(epa_observation_id IS NOT NULL)"
    t.index ["evidence_requirement_id", "evidence_date"], name: "idx_evidence_records_requirement_date"
    t.index ["evidence_requirement_id", "evidence_source_id"], name: "idx_evidence_record_source_once", unique: true, where: "(evidence_source_id IS NOT NULL)"
    t.index ["evidence_requirement_id", "mini_cex_evaluation_id"], name: "idx_evidence_record_mini_cex_once", unique: true, where: "(mini_cex_evaluation_id IS NOT NULL)"
    t.index ["evidence_requirement_id", "reflection_entry_id"], name: "idx_evidence_record_reflection_once", unique: true, where: "(reflection_entry_id IS NOT NULL)"
    t.index ["evidence_requirement_id", "wpba_observation_id"], name: "idx_evidence_records_requirement_wpba_observation", unique: true, where: "(wpba_observation_id IS NOT NULL)"
    t.index ["evidence_requirement_id"], name: "index_evidence_records_on_evidence_requirement_id"
    t.index ["evidence_requirement_version_id"], name: "index_evidence_records_on_evidence_requirement_version_id"
    t.index ["evidence_source_id"], name: "index_evidence_records_on_evidence_source_id"
    t.index ["mini_cex_evaluation_id"], name: "index_evidence_records_on_mini_cex_evaluation_id"
    t.index ["reflection_entry_id"], name: "index_evidence_records_on_reflection_entry_id"
    t.check_constraint "num_nonnulls(assessment_instance_id, activity_log_id, reflection_entry_id, epa_observation_id, mini_cex_evaluation_id, dops_evaluation_id, wpba_observation_id) = 1 OR num_nonnulls(assessment_instance_id, activity_log_id, reflection_entry_id, epa_observation_id, mini_cex_evaluation_id, dops_evaluation_id, wpba_observation_id) = 0 AND evidence_source_id IS NOT NULL", name: "chk_evidence_record_single_source"
    t.check_constraint "result::text = ANY (ARRAY['pass'::character varying::text, 'fail'::character varying::text, 'borderline'::character varying::text, 'not_assessed'::character varying::text, 'other'::character varying::text])", name: "chk_evidence_record_result"
  end

  create_table "evidence_requirement_versions", force: :cascade do |t|
    t.bigint "evidence_requirement_id", null: false
    t.integer "version", null: false
    t.jsonb "configuration", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["evidence_requirement_id", "version"], name: "idx_evidence_requirement_versions_unique_version", unique: true
    t.index ["evidence_requirement_id"], name: "index_evidence_requirement_versions_on_evidence_requirement_id"
  end

  create_table "evidence_requirements", force: :cascade do |t|
    t.bigint "competency_item_id"
    t.bigint "competency_indicator_id"
    t.bigint "epa_id"
    t.bigint "blueprint_item_id"
    t.bigint "assessment_method_id"
    t.string "origin", null: false
    t.string "source_type", null: false
    t.integer "required_count", default: 1, null: false
    t.jsonb "fulfillment_rule", default: {}, null: false
    t.string "due_stage"
    t.boolean "is_mandatory", default: true, null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assessment_method_id"], name: "index_evidence_requirements_on_assessment_method_id"
    t.index ["blueprint_item_id"], name: "index_evidence_requirements_on_blueprint_item_id"
    t.index ["competency_indicator_id"], name: "index_evidence_requirements_on_competency_indicator_id"
    t.index ["competency_item_id"], name: "index_evidence_requirements_on_competency_item_id"
    t.index ["epa_id"], name: "index_evidence_requirements_on_epa_id"
    t.check_constraint "competency_indicator_id IS NULL OR competency_item_id IS NOT NULL", name: "chk_evidence_indicator_target"
    t.check_constraint "competency_item_id IS NOT NULL OR epa_id IS NOT NULL", name: "chk_evidence_requirement_target"
    t.check_constraint "origin::text = 'blueprint'::text AND blueprint_item_id IS NOT NULL OR origin::text = 'manual'::text AND blueprint_item_id IS NULL", name: "chk_evidence_requirement_origin_source"
    t.check_constraint "origin::text = ANY (ARRAY['blueprint'::character varying::text, 'manual'::character varying::text])", name: "chk_evidence_requirement_origin"
    t.check_constraint "required_count > 0", name: "chk_evidence_requirement_count"
    t.check_constraint "source_type::text = ANY (ARRAY['assessment'::character varying::text, 'wpba'::character varying::text, 'logbook'::character varying::text, 'portfolio'::character varying::text, 'reflection'::character varying::text, 'other'::character varying::text, 'epa_observation'::character varying::text, 'external'::character varying::text])", name: "chk_evidence_requirement_source"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'inactive'::character varying::text])", name: "chk_evidence_requirement_status"
  end

  create_table "evidence_sources", force: :cascade do |t|
    t.bigint "student_id", null: false
    t.bigint "assessor_id"
    t.string "source_system", null: false
    t.string "source_type", null: false
    t.string "source_record_id", null: false
    t.string "source_revision", null: false
    t.string "activity_key", null: false
    t.date "occurred_on", null: false
    t.string "validation_status", default: "unverified", null: false
    t.string "instrument_code"
    t.string "instrument_version"
    t.decimal "score", precision: 8, scale: 3
    t.string "result"
    t.text "feedback"
    t.jsonb "context", default: {}, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "validated_at"
    t.bigint "validated_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assessor_id"], name: "index_evidence_sources_on_assessor_id"
    t.index ["source_system", "activity_key"], name: "idx_evidence_sources_activity_key"
    t.index ["source_system", "source_record_id", "source_revision"], name: "idx_evidence_sources_external_identity", unique: true
    t.index ["student_id"], name: "index_evidence_sources_on_student_id"
    t.index ["validated_by_id"], name: "index_evidence_sources_on_validated_by_id"
    t.check_constraint "source_type::text = ANY (ARRAY['assessment'::character varying::text, 'wpba'::character varying::text, 'logbook'::character varying::text, 'reflection'::character varying::text, 'epa_observation'::character varying::text, 'external'::character varying::text])", name: "chk_evidence_source_type"
    t.check_constraint "validation_status::text = ANY (ARRAY['unverified'::character varying::text, 'validated'::character varying::text, 'rejected'::character varying::text])", name: "chk_evidence_source_validation_status"
  end

  create_table "exam_imports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "imported_by_id", null: false
    t.string "kind", null: false
    t.string "name", null: false
    t.integer "row_count", default: 0, null: false
    t.integer "unmatched_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["imported_by_id"], name: "index_exam_imports_on_imported_by_id"
  end

  create_table "exam_scores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "exam_date", null: false
    t.bigint "exam_import_id", null: false
    t.decimal "max_score", precision: 6, scale: 2, default: "100.0", null: false
    t.decimal "score", precision: 6, scale: 2, null: false
    t.bigint "student_id", null: false
    t.datetime "updated_at", null: false
    t.index ["exam_import_id"], name: "index_exam_scores_on_exam_import_id"
    t.index ["student_id", "exam_date"], name: "index_exam_scores_on_student_id_and_exam_date"
    t.index ["student_id"], name: "index_exam_scores_on_student_id"
  end

  create_table "examiner_scores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "examiner_id", null: false
    t.text "feedback"
    t.bigint "final_project_id", null: false
    t.decimal "score", precision: 5, scale: 2, null: false
    t.date "session_date", null: false
    t.datetime "updated_at", null: false
    t.index ["examiner_id"], name: "index_examiner_scores_on_examiner_id"
    t.index ["final_project_id"], name: "index_examiner_scores_on_final_project_id"
  end

  create_table "external_identity_mappings", force: :cascade do |t|
    t.string "source_system", null: false
    t.string "entity_type", null: false
    t.string "external_id", null: false
    t.string "internal_record_type", null: false
    t.bigint "internal_record_id", null: false
    t.string "authority", default: "manual", null: false
    t.string "source_revision"
    t.datetime "last_synced_at"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_external_identity_mappings_on_created_by_id"
    t.index ["internal_record_type", "internal_record_id"], name: "idx_external_identity_internal_target"
    t.index ["source_system", "entity_type", "external_id"], name: "idx_external_identity_source_once", unique: true
    t.check_constraint "authority::text = ANY (ARRAY['manual'::character varying::text, 'import'::character varying::text, 'integration'::character varying::text])", name: "chk_external_identity_authority"
  end

  create_table "external_import_batches", force: :cascade do |t|
    t.bigint "study_program_id", null: false
    t.bigint "uploaded_by_id", null: false
    t.string "source_system", null: false
    t.string "filename", null: false
    t.string "file_sha256", null: false
    t.string "status", default: "previewed", null: false
    t.integer "row_count", default: 0, null: false
    t.integer "imported_count", default: 0, null: false
    t.jsonb "row_results", default: [], null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["study_program_id", "created_at"], name: "idx_external_import_batches_program_created"
    t.index ["study_program_id"], name: "index_external_import_batches_on_study_program_id"
    t.index ["uploaded_by_id"], name: "index_external_import_batches_on_uploaded_by_id"
  end

  create_table "external_mapping_events", force: :cascade do |t|
    t.bigint "external_identity_mapping_id", null: false
    t.bigint "changed_by_id", null: false
    t.bigint "previous_internal_record_id", null: false
    t.bigint "new_internal_record_id", null: false
    t.text "reason", null: false
    t.datetime "changed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["changed_by_id"], name: "index_external_mapping_events_on_changed_by_id"
    t.index ["external_identity_mapping_id", "changed_at"], name: "idx_external_mapping_change_history"
    t.index ["external_identity_mapping_id"], name: "index_external_mapping_events_on_external_identity_mapping_id"
  end

  create_table "final_project_milestones", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "final_project_id", null: false
    t.date "target_date", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["final_project_id"], name: "index_final_project_milestones_on_final_project_id"
  end

  create_table "final_projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "status", default: "proposal", null: false
    t.bigint "student_id", null: false
    t.bigint "supervisor_id"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["student_id"], name: "index_final_projects_on_student_id"
    t.index ["supervisor_id"], name: "index_final_projects_on_supervisor_id"
  end

  create_table "framework_template_records", force: :cascade do |t|
    t.string "name", null: false
    t.text "description", default: "", null: false
    t.string "source_name", default: "Adaptasi program studi", null: false
    t.string "source_version", default: "1", null: false
    t.string "template_version", default: "1.0.0", null: false
    t.text "attribution", default: "", null: false
    t.string "education_stage"
    t.jsonb "domains", default: [], null: false
    t.jsonb "provenance", default: {}, null: false
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_framework_template_records_on_created_by_id"
    t.index ["name"], name: "index_framework_template_records_on_name"
    t.check_constraint "education_stage IS NULL OR (education_stage::text = ANY (ARRAY['sarjana'::character varying::text, 'profesi'::character varying::text, 'spesialis'::character varying::text, 'subspesialis'::character varying::text]))", name: "chk_framework_template_education_stage"
  end

  create_table "glide_imports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "created_count", default: 0, null: false
    t.jsonb "created_event_ids", default: [], null: false
    t.jsonb "created_instance_ids", default: [], null: false
    t.integer "error_count", default: 0, null: false
    t.jsonb "error_messages", default: [], null: false
    t.string "filename"
    t.jsonb "filled_instance_ids", default: [], null: false
    t.bigint "imported_by_id"
    t.string "importer_key", null: false
    t.jsonb "options", default: {}, null: false
    t.datetime "rolled_back_at"
    t.bigint "rolled_back_by_id"
    t.jsonb "skip_reasons", default: {}, null: false
    t.integer "skipped_count", default: 0, null: false
    t.string "status", default: "completed", null: false
    t.integer "total_rows", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "updated_count", default: 0, null: false
    t.index ["imported_by_id"], name: "index_glide_imports_on_imported_by_id"
    t.index ["rolled_back_by_id"], name: "index_glide_imports_on_rolled_back_by_id"
  end

  create_table "learning_units", force: :cascade do |t|
    t.bigint "academic_period_id"
    t.bigint "assessment_blueprint_id"
    t.string "code"
    t.datetime "created_at", null: false
    t.integer "credits"
    t.text "description"
    t.string "name", null: false
    t.bigint "study_program_id", null: false
    t.datetime "updated_at", null: false
    t.index ["academic_period_id"], name: "index_learning_units_on_academic_period_id"
    t.index ["assessment_blueprint_id"], name: "index_learning_units_on_assessment_blueprint_id"
    t.index ["study_program_id", "academic_period_id", "name"], name: "idx_learning_units_unique", unique: true
    t.index ["study_program_id"], name: "index_learning_units_on_study_program_id"
  end

  create_table "logbook_case_targets", force: :cascade do |t|
    t.bigint "academic_period_id"
    t.datetime "created_at", null: false
    t.string "facility_type", null: false
    t.text "notes"
    t.bigint "study_program_id", null: false
    t.integer "target_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["academic_period_id"], name: "index_logbook_case_targets_on_academic_period_id"
    t.index ["study_program_id", "academic_period_id", "facility_type"], name: "idx_logbook_case_targets_unique", unique: true
    t.index ["study_program_id"], name: "index_logbook_case_targets_on_study_program_id"
  end

  create_table "medication_definitions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "category"
    t.datetime "created_at", null: false
    t.string "dosage_form"
    t.string "name", null: false
    t.string "strength"
    t.datetime "updated_at", null: false
    t.string "usual_dosage"
    t.index "lower((name)::text), COALESCE(strength, ''::character varying)", name: "idx_medication_definitions_unique", unique: true
  end

  create_table "mini_cex_evaluations", force: :cascade do |t|
    t.string "case_complexity"
    t.string "case_description", null: false
    t.bigint "clinical_case_id"
    t.bigint "clinical_rotation_id", null: false
    t.string "clinical_setting"
    t.datetime "created_at", null: false
    t.date "evaluated_at", null: false
    t.bigint "evaluator_id", null: false
    t.integer "feedback_minutes"
    t.string "global_rating"
    t.integer "observation_minutes"
    t.text "overall_feedback"
    t.string "patient_age_group"
    t.jsonb "scores", default: {}, null: false
    t.string "status", default: "submitted", null: false
    t.bigint "student_id", null: false
    t.datetime "updated_at", null: false
    t.string "video_recording_url"
    t.bigint "wpba_instrument_version_id"
    t.text "correction_reason"
    t.bigint "corrects_id"
    t.index ["clinical_case_id"], name: "index_mini_cex_evaluations_on_clinical_case_id"
    t.index ["clinical_rotation_id"], name: "index_mini_cex_evaluations_on_clinical_rotation_id"
    t.index ["corrects_id"], name: "index_mini_cex_evaluations_on_corrects_id", unique: true
    t.index ["evaluator_id"], name: "index_mini_cex_evaluations_on_evaluator_id"
    t.index ["student_id", "evaluated_at"], name: "index_mini_cex_evaluations_on_student_id_and_evaluated_at"
    t.index ["student_id"], name: "index_mini_cex_evaluations_on_student_id"
    t.index ["wpba_instrument_version_id"], name: "index_mini_cex_evaluations_on_wpba_instrument_version_id"
  end

  create_table "module_configuration_changes", force: :cascade do |t|
    t.bigint "study_program_id", null: false
    t.bigint "actor_id", null: false
    t.jsonb "before_value", default: {}, null: false
    t.jsonb "after_value", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_module_configuration_changes_on_actor_id"
    t.index ["study_program_id", "created_at"], name: "idx_module_config_changes_program_time"
    t.index ["study_program_id"], name: "index_module_configuration_changes_on_study_program_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.text "message"
    t.bigint "notifiable_id"
    t.string "notifiable_type"
    t.string "notification_type"
    t.datetime "read_at"
    t.bigint "recipient_id", null: false
    t.bigint "sender_id"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["recipient_id", "archived_at"], name: "index_notifications_on_recipient_id_and_archived_at"
    t.index ["recipient_id", "read_at"], name: "index_notifications_on_recipient_id_and_read_at"
    t.index ["recipient_id"], name: "index_notifications_on_recipient_id"
    t.index ["sender_id"], name: "index_notifications_on_sender_id"
  end

  create_table "osce_station_scores", force: :cascade do |t|
    t.datetime "assessed_at"
    t.bigint "assessment_instance_id", null: false
    t.string "case_title"
    t.decimal "checklist_score", precision: 6, scale: 2
    t.datetime "created_at", null: false
    t.jsonb "details", default: {}, null: false
    t.bigint "examiner_id"
    t.string "external_row_id"
    t.text "feedback_improve"
    t.text "feedback_keep"
    t.bigint "glide_import_id"
    t.string "global_rating"
    t.string "question_code"
    t.text "reflection"
    t.jsonb "scores", default: {}, null: false
    t.string "station"
    t.datetime "updated_at", null: false
    t.index ["assessment_instance_id"], name: "index_osce_station_scores_on_assessment_instance_id"
    t.index ["examiner_id"], name: "index_osce_station_scores_on_examiner_id"
    t.index ["external_row_id"], name: "index_osce_station_scores_on_external_row_id", unique: true, where: "(external_row_id IS NOT NULL)"
    t.index ["glide_import_id"], name: "index_osce_station_scores_on_glide_import_id"
  end

  create_table "patient_consents", force: :cascade do |t|
    t.bigint "clinical_case_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "items", default: {}, null: false
    t.datetime "revoked_at"
    t.datetime "signed_at"
    t.string "signer_name"
    t.string "signer_relation"
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["clinical_case_id"], name: "index_patient_consents_on_clinical_case_id", unique: true
    t.index ["token"], name: "index_patient_consents_on_token", unique: true
  end

  create_table "portfolio_selections", force: :cascade do |t|
    t.bigint "artifact_submission_id", null: false
    t.bigint "student_id", null: false
    t.string "visibility", default: "private", null: false
    t.datetime "selected_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["artifact_submission_id"], name: "index_portfolio_selections_on_artifact_submission_id", unique: true
    t.index ["student_id"], name: "index_portfolio_selections_on_student_id"
    t.check_constraint "visibility::text = ANY (ARRAY['private'::character varying::text, 'assigned_reviewers'::character varying::text])", name: "chk_portfolio_selection_visibility"
  end

  create_table "prescription_items", force: :cascade do |t|
    t.bigint "clinical_case_id", null: false
    t.datetime "created_at", null: false
    t.string "dosage_form"
    t.string "medication_name", null: false
    t.string "notes"
    t.integer "position", default: 0, null: false
    t.string "quantity"
    t.string "route"
    t.string "signa"
    t.string "strength"
    t.datetime "updated_at", null: false
    t.index ["clinical_case_id"], name: "index_prescription_items_on_clinical_case_id"
  end

  create_table "rbac_audit_events", force: :cascade do |t|
    t.bigint "actor_user_id"
    t.bigint "subject_user_id"
    t.bigint "role_id"
    t.string "event_key", null: false
    t.jsonb "details", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_user_id"], name: "index_rbac_audit_events_on_actor_user_id"
    t.index ["event_key", "created_at"], name: "index_rbac_audit_events_on_event_key_and_created_at"
    t.index ["role_id"], name: "index_rbac_audit_events_on_role_id"
    t.index ["subject_user_id"], name: "index_rbac_audit_events_on_subject_user_id"
  end

  create_table "reflection_entries", force: :cascade do |t|
    t.bigint "activity_log_id"
    t.bigint "clinical_case_id"
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.date "entry_date", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.text "what_happened"
    t.text "what_learned"
    t.text "what_to_improve"
    t.text "next_action"
    t.index ["activity_log_id"], name: "index_reflection_entries_on_activity_log_id"
    t.index ["clinical_case_id"], name: "index_reflection_entries_on_clinical_case_id"
    t.index ["user_id", "entry_date"], name: "index_reflection_entries_on_user_id_and_entry_date"
    t.index ["user_id"], name: "index_reflection_entries_on_user_id"
  end

  create_table "reflection_entry_competency_tags", force: :cascade do |t|
    t.bigint "reflection_entry_id", null: false
    t.bigint "competency_item_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["competency_item_id"], name: "index_reflection_entry_competency_tags_on_competency_item_id"
    t.index ["reflection_entry_id", "competency_item_id"], name: "idx_reflection_competency_tags_unique", unique: true
    t.index ["reflection_entry_id"], name: "index_reflection_entry_competency_tags_on_reflection_entry_id"
  end

  create_table "reflection_entry_evidence_sources", force: :cascade do |t|
    t.bigint "reflection_entry_id", null: false
    t.bigint "evidence_source_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["evidence_source_id"], name: "index_reflection_entry_evidence_sources_on_evidence_source_id"
    t.index ["reflection_entry_id", "evidence_source_id"], name: "idx_reflection_evidence_sources_unique", unique: true
    t.index ["reflection_entry_id"], name: "index_reflection_entry_evidence_sources_on_reflection_entry_id"
  end

  create_table "role_permissions", force: :cascade do |t|
    t.bigint "role_id", null: false
    t.bigint "system_permission_id", null: false
    t.string "scope_level", default: "study_program", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["role_id", "system_permission_id"], name: "idx_role_permissions_unique", unique: true
    t.index ["role_id"], name: "index_role_permissions_on_role_id"
    t.index ["system_permission_id"], name: "index_role_permissions_on_system_permission_id"
    t.check_constraint "scope_level::text = ANY (ARRAY['system'::character varying::text, 'study_program'::character varying::text])", name: "chk_role_permissions_scope"
  end

  create_table "roles", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_roles_on_code", unique: true
  end

  create_table "skill_definitions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "category"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "skdi_level"
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "idx_skill_definitions_lower_name", unique: true
  end

  create_table "srq_screenings", force: :cascade do |t|
    t.text "answers", null: false
    t.datetime "consented_at", null: false
    t.datetime "created_at", null: false
    t.text "follow_up_note"
    t.datetime "followed_up_at"
    t.bigint "followed_up_by_id"
    t.date "screened_on", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["followed_up_by_id"], name: "index_srq_screenings_on_followed_up_by_id"
    t.index ["user_id", "screened_on"], name: "index_srq_screenings_on_user_id_and_screened_on", unique: true
  end

  create_table "study_programs", force: :cascade do |t|
    t.string "code"
    t.bigint "competency_framework_id"
    t.datetime "created_at", null: false
    t.string "level"
    t.string "name", null: false
    t.datetime "srq_enabled_at"
    t.bigint "srq_enabled_by_id"
    t.datetime "updated_at", null: false
    t.integer "epa_panel_quorum", default: 1, null: false
    t.index ["code"], name: "index_study_programs_on_code", unique: true
    t.index ["competency_framework_id"], name: "index_study_programs_on_competency_framework_id"
    t.index ["name"], name: "index_study_programs_on_name", unique: true
    t.index ["srq_enabled_by_id"], name: "index_study_programs_on_srq_enabled_by_id"
    t.check_constraint "epa_panel_quorum >= 1 AND epa_panel_quorum <= 10", name: "chk_study_program_epa_panel_quorum"
  end

  create_table "supervision_levels", force: :cascade do |t|
    t.bigint "supervision_scale_version_id", null: false
    t.integer "ordinal", null: false
    t.string "code", null: false
    t.string "label", null: false
    t.text "description", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["supervision_scale_version_id", "code"], name: "idx_supervision_levels_code", unique: true
    t.index ["supervision_scale_version_id", "ordinal"], name: "idx_supervision_levels_ordinal", unique: true
    t.index ["supervision_scale_version_id"], name: "index_supervision_levels_on_supervision_scale_version_id"
  end

  create_table "supervision_scale_versions", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.string "version_label", null: false
    t.string "use_case", null: false
    t.text "source_reference"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code", "version_label"], name: "idx_supervision_scale_versions_identity", unique: true
    t.check_constraint "use_case::text = ANY (ARRAY['retrospective_observation'::character varying::text, 'prospective_entrustment'::character varying::text])", name: "chk_supervision_scale_use_case"
  end

  create_table "system_permissions", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.text "description", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_system_permissions_on_key", unique: true
  end

  create_table "terminology_overrides", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.bigint "updated_by_id"
    t.string "value", null: false
    t.index ["key"], name: "index_terminology_overrides_on_key", unique: true
    t.index ["updated_by_id"], name: "index_terminology_overrides_on_updated_by_id"
  end

  create_table "tutorial_enrollments", force: :cascade do |t|
    t.bigint "academic_period_id", null: false
    t.boolean "active", default: true, null: false
    t.string "block_name", null: false
    t.datetime "created_at", null: false
    t.date "end_date"
    t.string "group_name"
    t.date "start_date"
    t.bigint "tutor_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["academic_period_id"], name: "index_tutorial_enrollments_on_academic_period_id"
    t.index ["tutor_id"], name: "index_tutorial_enrollments_on_tutor_id"
    t.index ["user_id", "academic_period_id", "block_name"], name: "idx_tutorial_enrollments_unique_block", unique: true
    t.index ["user_id"], name: "index_tutorial_enrollments_on_user_id"
  end

  create_table "user_assignments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "assigned_by_id", null: false
    t.bigint "study_program_id"
    t.string "assignment_role", null: false
    t.string "scope_type"
    t.bigint "scope_id"
    t.date "starts_on"
    t.date "ends_on"
    t.datetime "revoked_at"
    t.text "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "revoked_by_id"
    t.index ["assigned_by_id"], name: "index_user_assignments_on_assigned_by_id"
    t.index ["study_program_id"], name: "index_user_assignments_on_study_program_id"
    t.index ["user_id", "assignment_role"], name: "idx_user_assignments_scope"
    t.index ["user_id"], name: "index_user_assignments_on_user_id"
    t.check_constraint "ends_on IS NULL OR starts_on IS NULL OR ends_on >= starts_on", name: "chk_user_assignment_dates"
  end

  create_table "user_roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "scope_level", default: "system", null: false
    t.bigint "study_program_id"
    t.index ["role_id"], name: "index_user_roles_on_role_id"
    t.index ["study_program_id"], name: "index_user_roles_on_study_program_id"
    t.index ["user_id", "role_id", "study_program_id"], name: "idx_user_roles_program_scope", unique: true, where: "((scope_level)::text = 'study_program'::text)"
    t.index ["user_id", "role_id"], name: "idx_user_roles_system_scope", unique: true, where: "((scope_level)::text = 'system'::text)"
    t.index ["user_id", "role_id"], name: "idx_user_roles_unassigned_scope", unique: true, where: "((scope_level)::text = 'unassigned'::text)"
    t.index ["user_id"], name: "index_user_roles_on_user_id"
    t.check_constraint "scope_level::text = 'system'::text AND study_program_id IS NULL OR scope_level::text = 'study_program'::text AND study_program_id IS NOT NULL OR scope_level::text = 'unassigned'::text AND study_program_id IS NULL", name: "chk_user_roles_scope"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "active_role_id"
    t.text "address"
    t.date "birth_date"
    t.string "birth_place"
    t.string "calendar_feed_token"
    t.integer "cohort_year"
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.datetime "deactivated_at"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.string "font_size_preference", default: "normal", null: false
    t.string "full_name", default: "", null: false
    t.string "gender"
    t.string "identifier_number"
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.string "locale_preference", default: "id", null: false
    t.datetime "locked_at"
    t.boolean "must_change_password", default: false, null: false
    t.string "phone"
    t.string "position"
    t.string "profession_category"
    t.string "provider"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.string "specialization"
    t.bigint "study_program_id"
    t.string "theme_preference", default: "system", null: false
    t.string "uid"
    t.string "unconfirmed_email"
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.string "work_unit"
    t.index ["active_role_id"], name: "index_users_on_active_role_id"
    t.index ["calendar_feed_token"], name: "index_users_on_calendar_feed_token", unique: true
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["identifier_number"], name: "index_users_on_identifier_number"
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["study_program_id"], name: "index_users_on_study_program_id"
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "wpba_instrument_versions", force: :cascade do |t|
    t.bigint "wpba_instrument_id", null: false
    t.string "version_label", null: false
    t.jsonb "definition", default: {}, null: false
    t.datetime "published_at"
    t.bigint "published_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["published_by_id"], name: "index_wpba_instrument_versions_on_published_by_id"
    t.index ["wpba_instrument_id", "version_label"], name: "idx_wpba_instrument_versions_unique", unique: true
    t.index ["wpba_instrument_id"], name: "index_wpba_instrument_versions_on_wpba_instrument_id"
  end

  create_table "wpba_instruments", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.string "instrument_type", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_wpba_instruments_on_code", unique: true
  end

  create_table "wpba_observations", force: :cascade do |t|
    t.bigint "student_id", null: false
    t.bigint "observer_id", null: false
    t.bigint "clinical_rotation_id", null: false
    t.bigint "clinical_case_id"
    t.bigint "wpba_instrument_version_id", null: false
    t.bigint "corrects_id"
    t.datetime "observed_at", null: false
    t.string "status", default: "draft", null: false
    t.text "activity_summary"
    t.jsonb "clinical_context", default: {}, null: false
    t.jsonb "responses", default: {}, null: false
    t.text "overall_feedback"
    t.text "action_plan"
    t.text "correction_reason"
    t.datetime "submitted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["clinical_case_id"], name: "index_wpba_observations_on_clinical_case_id"
    t.index ["clinical_rotation_id"], name: "index_wpba_observations_on_clinical_rotation_id"
    t.index ["corrects_id"], name: "index_wpba_observations_on_corrects_id", unique: true
    t.index ["observer_id", "observed_at"], name: "index_wpba_observations_on_observer_id_and_observed_at"
    t.index ["observer_id"], name: "index_wpba_observations_on_observer_id"
    t.index ["student_id", "observed_at"], name: "index_wpba_observations_on_student_id_and_observed_at"
    t.index ["student_id"], name: "index_wpba_observations_on_student_id"
    t.index ["wpba_instrument_version_id"], name: "index_wpba_observations_on_wpba_instrument_version_id"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'submitted'::character varying::text])", name: "chk_wpba_observations_status"
  end

  add_foreign_key "academic_activity_subdomains", "academic_activity_domains"
  add_foreign_key "academic_activity_templates", "academic_activity_subdomains"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activity_log_competency_tags", "activity_logs"
  add_foreign_key "activity_log_competency_tags", "competency_items"
  add_foreign_key "activity_logs", "academic_activity_domains"
  add_foreign_key "activity_logs", "academic_activity_subdomains"
  add_foreign_key "activity_logs", "academic_activity_templates"
  add_foreign_key "activity_logs", "academic_periods"
  add_foreign_key "activity_logs", "clinical_rotations"
  add_foreign_key "activity_logs", "users"
  add_foreign_key "activity_logs", "users", column: "verified_by_id"
  add_foreign_key "app_settings", "users", column: "updated_by_id"
  add_foreign_key "artifact_submission_reviews", "artifact_submissions"
  add_foreign_key "artifact_submission_reviews", "users", column: "reviewer_id"
  add_foreign_key "artifact_submissions", "users", column: "reviewer_id"
  add_foreign_key "artifact_submissions", "users", column: "student_id"
  add_foreign_key "assessment_blueprint_mappings", "assessment_blueprints"
  add_foreign_key "assessment_blueprint_mappings", "competency_items"
  add_foreign_key "assessment_blueprints", "study_programs"
  add_foreign_key "assessment_dimension_scores", "assessment_dimensions"
  add_foreign_key "assessment_dimension_scores", "assessment_instances"
  add_foreign_key "assessment_dimensions", "assessment_events"
  add_foreign_key "assessment_dimensions", "competency_items"
  add_foreign_key "assessment_events", "academic_periods"
  add_foreign_key "assessment_events", "assessment_form_templates"
  add_foreign_key "assessment_events", "blueprint_items"
  add_foreign_key "assessment_events", "study_programs"
  add_foreign_key "assessment_events", "users", column: "created_by_id"
  add_foreign_key "assessment_events", "wpba_instrument_versions"
  add_foreign_key "assessment_form_answers", "assessment_form_fields"
  add_foreign_key "assessment_form_answers", "assessment_form_submissions"
  add_foreign_key "assessment_form_fields", "assessment_form_templates"
  add_foreign_key "assessment_form_fields", "competency_items"
  add_foreign_key "assessment_form_submissions", "assessment_form_templates"
  add_foreign_key "assessment_form_submissions", "users", column: "respondent_id"
  add_foreign_key "assessment_form_submissions", "users", column: "subject_user_id"
  add_foreign_key "assessment_form_templates", "study_programs"
  add_foreign_key "assessment_form_templates", "users", column: "created_by_id"
  add_foreign_key "assessment_instances", "assessment_events"
  add_foreign_key "assessment_instances", "assessment_form_submissions"
  add_foreign_key "assessment_instances", "clinical_cases"
  add_foreign_key "assessment_instances", "users", column: "examiner_id"
  add_foreign_key "assessment_instances", "users", column: "student_id"
  add_foreign_key "assessment_mappings", "assessment_events"
  add_foreign_key "assessment_mappings", "learning_units"
  add_foreign_key "blueprint_item_competencies", "blueprint_items"
  add_foreign_key "blueprint_item_competencies", "competency_indicators"
  add_foreign_key "blueprint_item_competencies", "competency_items"
  add_foreign_key "blueprint_item_epas", "blueprint_items"
  add_foreign_key "blueprint_item_epas", "epas"
  add_foreign_key "blueprint_item_epas", "supervision_levels"
  add_foreign_key "blueprint_items", "assessment_methods"
  add_foreign_key "blueprint_items", "blueprint_versions"
  add_foreign_key "blueprint_versions", "assessment_blueprints"
  add_foreign_key "blueprint_versions", "competency_frameworks"
  add_foreign_key "break_glass_accesses", "clinical_cases"
  add_foreign_key "break_glass_accesses", "users"
  add_foreign_key "case_verification_comments", "clinical_cases"
  add_foreign_key "case_verification_comments", "users"
  add_foreign_key "clinical_cases", "users"
  add_foreign_key "clinical_cases", "users", column: "supervisor_id"
  add_foreign_key "clinical_cases", "users", column: "verified_by_id"
  add_foreign_key "clinical_rotations", "academic_periods"
  add_foreign_key "clinical_rotations", "users"
  add_foreign_key "clinical_rotations", "users", column: "preceptor_id"
  add_foreign_key "competency_attainment_reviews", "competency_attainments"
  add_foreign_key "competency_attainment_reviews", "users", column: "reviewer_id"
  add_foreign_key "competency_attainments", "competency_items"
  add_foreign_key "competency_attainments", "users", column: "decision_by_id"
  add_foreign_key "competency_attainments", "users", column: "reviewed_by_id"
  add_foreign_key "competency_attainments", "users", column: "student_id"
  add_foreign_key "competency_frameworks", "study_programs"
  add_foreign_key "competency_indicators", "competency_items"
  add_foreign_key "competency_items", "competency_frameworks"
  add_foreign_key "competency_items", "competency_items", column: "parent_id"
  add_foreign_key "competency_milestones", "academic_periods"
  add_foreign_key "competency_milestones", "competency_items"
  add_foreign_key "competency_progressions", "competency_items", column: "source_competency_id"
  add_foreign_key "competency_progressions", "competency_items", column: "target_competency_id"
  add_foreign_key "data_export_logs", "users"
  add_foreign_key "device_push_tokens", "users"
  add_foreign_key "dops_evaluations", "clinical_cases"
  add_foreign_key "dops_evaluations", "clinical_rotations"
  add_foreign_key "dops_evaluations", "dops_evaluations", column: "corrects_id", name: "fk_dops_correction_parent", on_delete: :restrict
  add_foreign_key "dops_evaluations", "users", column: "evaluator_id"
  add_foreign_key "dops_evaluations", "users", column: "student_id"
  add_foreign_key "dops_evaluations", "wpba_instrument_versions"
  add_foreign_key "entrustment_decision_events", "entrustment_decisions"
  add_foreign_key "entrustment_decision_events", "users", column: "actor_id"
  add_foreign_key "entrustment_decisions", "clinical_cases"
  add_foreign_key "entrustment_decisions", "competency_items"
  add_foreign_key "entrustment_decisions", "entrustment_decisions", column: "superseded_by_id"
  add_foreign_key "entrustment_decisions", "epa_promotions"
  add_foreign_key "entrustment_decisions", "epa_promotions", column: "revocation_epa_promotion_id"
  add_foreign_key "entrustment_decisions", "epas"
  add_foreign_key "entrustment_decisions", "supervision_levels"
  add_foreign_key "entrustment_decisions", "users", column: "decided_by_id"
  add_foreign_key "entrustment_decisions", "users", column: "revoked_by_id"
  add_foreign_key "entrustment_decisions", "users", column: "student_id"
  add_foreign_key "epa_competencies", "competency_indicators"
  add_foreign_key "epa_competencies", "competency_items"
  add_foreign_key "epa_competencies", "epas"
  add_foreign_key "epa_milestones", "epas"
  add_foreign_key "epa_milestones", "supervision_levels"
  add_foreign_key "epa_observations", "clinical_cases"
  add_foreign_key "epa_observations", "clinical_rotations"
  add_foreign_key "epa_observations", "epas"
  add_foreign_key "epa_observations", "supervision_levels"
  add_foreign_key "epa_observations", "users", column: "observer_id"
  add_foreign_key "epa_observations", "users", column: "safety_resolved_by_id"
  add_foreign_key "epa_observations", "users", column: "student_id"
  add_foreign_key "epa_promotion_appeals", "epa_promotions"
  add_foreign_key "epa_promotion_appeals", "users", column: "appealed_by_id"
  add_foreign_key "epa_promotion_appeals", "users", column: "resolved_by_id"
  add_foreign_key "epa_promotion_review_events", "epa_promotion_reviews"
  add_foreign_key "epa_promotion_review_events", "supervision_levels"
  add_foreign_key "epa_promotion_reviews", "epa_promotions"
  add_foreign_key "epa_promotion_reviews", "supervision_levels"
  add_foreign_key "epa_promotion_reviews", "users", column: "reviewer_id"
  add_foreign_key "epa_promotions", "entrustment_decisions", column: "renewal_of_decision_id"
  add_foreign_key "epa_promotions", "epas"
  add_foreign_key "epa_promotions", "users", column: "finalized_by_id"
  add_foreign_key "epa_promotions", "users", column: "promoted_by_id"
  add_foreign_key "epa_promotions", "users", column: "reviewed_by_id"
  add_foreign_key "epa_promotions", "users", column: "student_id"
  add_foreign_key "epas", "competency_frameworks"
  add_foreign_key "evaluation_schedules", "clinical_rotations"
  add_foreign_key "evaluation_schedules", "users", column: "evaluator_id"
  add_foreign_key "evaluation_schedules", "users", column: "student_id"
  add_foreign_key "evidence_records", "activity_logs"
  add_foreign_key "evidence_records", "assessment_instances"
  add_foreign_key "evidence_records", "dops_evaluations"
  add_foreign_key "evidence_records", "epa_observations"
  add_foreign_key "evidence_records", "evidence_requirement_versions"
  add_foreign_key "evidence_records", "evidence_requirements"
  add_foreign_key "evidence_records", "evidence_sources"
  add_foreign_key "evidence_records", "mini_cex_evaluations"
  add_foreign_key "evidence_records", "reflection_entries"
  add_foreign_key "evidence_records", "wpba_observations"
  add_foreign_key "evidence_requirement_versions", "evidence_requirements"
  add_foreign_key "evidence_requirements", "assessment_methods"
  add_foreign_key "evidence_requirements", "blueprint_items"
  add_foreign_key "evidence_requirements", "competency_indicators"
  add_foreign_key "evidence_requirements", "competency_items"
  add_foreign_key "evidence_requirements", "epas"
  add_foreign_key "evidence_sources", "users", column: "assessor_id"
  add_foreign_key "evidence_sources", "users", column: "student_id"
  add_foreign_key "evidence_sources", "users", column: "validated_by_id"
  add_foreign_key "exam_imports", "users", column: "imported_by_id"
  add_foreign_key "exam_scores", "exam_imports"
  add_foreign_key "exam_scores", "users", column: "student_id"
  add_foreign_key "examiner_scores", "final_projects"
  add_foreign_key "examiner_scores", "users", column: "examiner_id"
  add_foreign_key "external_identity_mappings", "users", column: "created_by_id"
  add_foreign_key "external_import_batches", "study_programs"
  add_foreign_key "external_import_batches", "users", column: "uploaded_by_id"
  add_foreign_key "external_mapping_events", "external_identity_mappings"
  add_foreign_key "external_mapping_events", "users", column: "changed_by_id"
  add_foreign_key "final_project_milestones", "final_projects"
  add_foreign_key "final_projects", "users", column: "student_id"
  add_foreign_key "final_projects", "users", column: "supervisor_id"
  add_foreign_key "framework_template_records", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "glide_imports", "users", column: "imported_by_id"
  add_foreign_key "glide_imports", "users", column: "rolled_back_by_id"
  add_foreign_key "learning_units", "academic_periods"
  add_foreign_key "learning_units", "assessment_blueprints"
  add_foreign_key "learning_units", "study_programs"
  add_foreign_key "logbook_case_targets", "academic_periods"
  add_foreign_key "logbook_case_targets", "study_programs"
  add_foreign_key "mini_cex_evaluations", "clinical_cases"
  add_foreign_key "mini_cex_evaluations", "clinical_rotations"
  add_foreign_key "mini_cex_evaluations", "mini_cex_evaluations", column: "corrects_id", name: "fk_minicex_correction_parent", on_delete: :restrict
  add_foreign_key "mini_cex_evaluations", "users", column: "evaluator_id"
  add_foreign_key "mini_cex_evaluations", "users", column: "student_id"
  add_foreign_key "mini_cex_evaluations", "wpba_instrument_versions"
  add_foreign_key "module_configuration_changes", "study_programs"
  add_foreign_key "module_configuration_changes", "users", column: "actor_id"
  add_foreign_key "notifications", "users", column: "recipient_id"
  add_foreign_key "notifications", "users", column: "sender_id"
  add_foreign_key "osce_station_scores", "assessment_instances"
  add_foreign_key "osce_station_scores", "glide_imports"
  add_foreign_key "osce_station_scores", "users", column: "examiner_id"
  add_foreign_key "patient_consents", "clinical_cases"
  add_foreign_key "portfolio_selections", "artifact_submissions"
  add_foreign_key "portfolio_selections", "users", column: "student_id"
  add_foreign_key "prescription_items", "clinical_cases"
  add_foreign_key "rbac_audit_events", "users", column: "actor_user_id", on_delete: :nullify
  add_foreign_key "rbac_audit_events", "users", column: "subject_user_id", on_delete: :nullify
  add_foreign_key "reflection_entries", "activity_logs"
  add_foreign_key "reflection_entries", "clinical_cases"
  add_foreign_key "reflection_entries", "users"
  add_foreign_key "reflection_entry_competency_tags", "competency_items"
  add_foreign_key "reflection_entry_competency_tags", "reflection_entries"
  add_foreign_key "reflection_entry_evidence_sources", "evidence_sources"
  add_foreign_key "reflection_entry_evidence_sources", "reflection_entries"
  add_foreign_key "role_permissions", "roles"
  add_foreign_key "role_permissions", "system_permissions"
  add_foreign_key "srq_screenings", "users"
  add_foreign_key "srq_screenings", "users", column: "followed_up_by_id"
  add_foreign_key "study_programs", "competency_frameworks"
  add_foreign_key "study_programs", "users", column: "srq_enabled_by_id"
  add_foreign_key "supervision_levels", "supervision_scale_versions"
  add_foreign_key "terminology_overrides", "users", column: "updated_by_id"
  add_foreign_key "tutorial_enrollments", "academic_periods"
  add_foreign_key "tutorial_enrollments", "users"
  add_foreign_key "tutorial_enrollments", "users", column: "tutor_id"
  add_foreign_key "user_assignments", "study_programs"
  add_foreign_key "user_assignments", "users"
  add_foreign_key "user_assignments", "users", column: "assigned_by_id"
  add_foreign_key "user_assignments", "users", column: "revoked_by_id"
  add_foreign_key "user_roles", "roles"
  add_foreign_key "user_roles", "study_programs"
  add_foreign_key "user_roles", "users"
  add_foreign_key "users", "roles", column: "active_role_id"
  add_foreign_key "users", "study_programs"
  add_foreign_key "wpba_instrument_versions", "users", column: "published_by_id"
  add_foreign_key "wpba_instrument_versions", "wpba_instruments"
  add_foreign_key "wpba_observations", "clinical_cases"
  add_foreign_key "wpba_observations", "clinical_rotations"
  add_foreign_key "wpba_observations", "users", column: "observer_id"
  add_foreign_key "wpba_observations", "users", column: "student_id"
  add_foreign_key "wpba_observations", "wpba_instrument_versions"
  add_foreign_key "wpba_observations", "wpba_observations", column: "corrects_id", name: "fk_wpba_observations_correction_parent", on_delete: :restrict
end
