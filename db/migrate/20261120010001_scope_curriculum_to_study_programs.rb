# frozen_string_literal: true

class ScopeCurriculumToStudyPrograms < ActiveRecord::Migration[8.1]
  class LegacyStudyProgram < ActiveRecord::Base
    self.table_name = "study_programs"
  end

  class LegacyFramework < ActiveRecord::Base
    self.table_name = "competency_frameworks"
  end

  class LegacyBlueprint < ActiveRecord::Base
    self.table_name = "assessment_blueprints"
  end

  class LegacyLearningUnit < ActiveRecord::Base
    self.table_name = "learning_units"
  end

  def up
    add_reference :competency_frameworks, :study_program, index: { unique: true }, foreign_key: true
    add_reference :assessment_blueprints, :study_program, index: { unique: true }, foreign_key: true
    add_column :competency_items, :expected_evidence_text, :text
    add_column :competency_items, :expected_evidence_types, :jsonb, null: false, default: []

    backfill_frameworks
    backfill_blueprints

    change_column_null :competency_frameworks, :study_program_id, false
    change_column_null :assessment_blueprints, :study_program_id, false
  end

  def down
    remove_column :competency_items, :expected_evidence_types
    remove_column :competency_items, :expected_evidence_text
    remove_reference :assessment_blueprints, :study_program, foreign_key: true
    remove_reference :competency_frameworks, :study_program, foreign_key: true
  end

  private

  def backfill_frameworks
    return unless LegacyFramework.exists?

    program = LegacyStudyProgram.find_by(code: "pssk") || LegacyStudyProgram.order(:id).first
    raise "Cannot assign existing competency frameworks: no study programs exist" unless program

    LegacyFramework.where(study_program_id: nil).order(:id).each_with_index do |framework, index|
      target = index.zero? ? program : LegacyStudyProgram.order(:id).offset(index).first || program
      framework.update_columns(study_program_id: target.id)
    end
  end

  def backfill_blueprints
    return unless LegacyBlueprint.exists?

    fallback = LegacyStudyProgram.find_by(code: "pspd") || LegacyStudyProgram.order(:id).first
    raise "Cannot assign existing assessment blueprints: no study programs exist" unless fallback

    LegacyBlueprint.where(study_program_id: nil).order(:id).each do |blueprint|
      program_id = LegacyLearningUnit.where(assessment_blueprint_id: blueprint.id)
        .group(:study_program_id).order(Arel.sql("COUNT(*) DESC")).limit(1).pick(:study_program_id)
      blueprint.update_columns(study_program_id: program_id || fallback.id)
    end
  end
end
