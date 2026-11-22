# frozen_string_literal: true

class UseStudyProgramLevelCodesForEducationStages < ActiveRecord::Migration[8.1]
  LEGACY_TO_PROGRAM_LEVEL = {
    "undergraduate" => "sarjana",
    "professional" => "profesi",
    "specialist" => "spesialis",
    "subspecialist" => "subspesialis"
  }.freeze

  PROGRAM_LEVEL_TO_LEGACY = LEGACY_TO_PROGRAM_LEVEL.invert.freeze

  def up
    safety_assured do
      remove_check_constraint :competency_frameworks, name: "chk_framework_education_stage"
      translate_values(LEGACY_TO_PROGRAM_LEVEL)
      add_stage_constraints(%w[sarjana profesi spesialis subspesialis])
    end
  end

  def down
    safety_assured do
      remove_check_constraint :competency_frameworks, name: "chk_framework_education_stage"
      remove_check_constraint :epa_milestones, name: "chk_epa_milestone_stage"
      remove_check_constraint :framework_template_records, name: "chk_framework_template_education_stage"
      translate_values(PROGRAM_LEVEL_TO_LEGACY)
      add_stage_constraints(%w[undergraduate professional specialist subspecialist])
    end
  end

  private

  def translate_values(mapping)
    mapping.each do |source, target|
      execute <<~SQL
        UPDATE competency_frameworks
        SET education_stage = #{connection.quote(target)}
        WHERE education_stage = #{connection.quote(source)}
      SQL
      execute <<~SQL
        UPDATE epa_milestones
        SET stage = #{connection.quote(target)}
        WHERE stage = #{connection.quote(source)}
      SQL
      execute <<~SQL
        UPDATE framework_template_records
        SET education_stage = #{connection.quote(target)}
        WHERE education_stage = #{connection.quote(source)}
      SQL
    end
  end

  def add_stage_constraints(values)
    quoted = values.map { |value| connection.quote(value) }.join(", ")
    add_check_constraint :competency_frameworks,
      "education_stage IS NULL OR education_stage IN (#{quoted})",
      name: "chk_framework_education_stage", validate: false
    add_check_constraint :epa_milestones, "stage IN (#{quoted})",
      name: "chk_epa_milestone_stage", validate: false
    add_check_constraint :framework_template_records,
      "education_stage IS NULL OR education_stage IN (#{quoted})",
      name: "chk_framework_template_education_stage", validate: false
    validate_check_constraint :competency_frameworks, name: "chk_framework_education_stage"
    validate_check_constraint :epa_milestones, name: "chk_epa_milestone_stage"
    validate_check_constraint :framework_template_records, name: "chk_framework_template_education_stage"
  end
end
