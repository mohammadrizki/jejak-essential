# frozen_string_literal: true

# Program-scoped switches for local workflows and normalized external payload
# adapters. External transport/health checks are deployment-specific and are
# intentionally not implied by enabling an adapter.
class ModuleConfiguration
  MODULE_KEYS = %w[
    core_eportfolio clinical_logbook wpba epa
    integration_sia integration_moodle integration_examtool integration_osce integration_clinical_wpba
  ].freeze

  attr_reader :study_program, :modules

  def self.for(study_program)
    new(study_program)
  end

  def initialize(study_program)
    @study_program = study_program
    @modules = default_modules
    row = setting_row
    @modules.merge!((row&.value || {}).fetch("modules", {}).slice(*MODULE_KEYS))
    @modules["core_eportfolio"] = true
  end

  def enabled?(key)
    return true if key.to_s == "core_eportfolio"

    @modules.fetch(key.to_s, false) == true
  end

  def update!(values, actor:)
    raise ArgumentError, "program studi wajib dipilih" if study_program.blank?
    unless actor.has_role?("admin") ||
        (actor.has_role?("kaprodi") && actor.study_program_id == study_program.id)
      raise Pundit::NotAuthorizedError, "Anda tidak berwenang mengatur modul program studi ini."
    end

    submitted = values.to_h.stringify_keys.slice(*MODULE_KEYS).transform_values do |value|
      ActiveModel::Type::Boolean.new.cast(value)
    end
    after_value = @modules.merge(submitted).merge("core_eportfolio" => true)
    validate_configuration!(after_value)
    before_value = @modules.dup
    return self if before_value == after_value

    ActiveRecord::Base.transaction do
      row = setting_row || AppSetting.new(key: setting_key)
      row.value = { "modules" => after_value }
      row.updated_by = actor
      row.save!
      ModuleConfigurationChange.create!(study_program: study_program, actor: actor,
        before_value: before_value, after_value: after_value)
    end
    @modules = after_value
    self
  end

  private

  def setting_key
    "module_configuration:study_program:#{study_program.id}"
  end

  def setting_row
    return if study_program.blank?

    AppSetting.find_by(key: setting_key)
  end

  def default_modules
    {
      "core_eportfolio" => true,
      "clinical_logbook" => true,
      "wpba" => true,
      "epa" => study_program&.level.in?(%w[profesi spesialis subspesialis]),
      "integration_sia" => false,
      "integration_moodle" => false,
      "integration_examtool" => false,
      "integration_osce" => false,
      "integration_clinical_wpba" => false
    }
  end

  def validate_configuration!(value)
    errors = []
    errors << "Core E-Portfolio selalu aktif." unless value["core_eportfolio"]
    raise ArgumentError, errors.join(" ") if errors.any?
  end
end
