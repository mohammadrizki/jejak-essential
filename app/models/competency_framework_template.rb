# frozen_string_literal: true

require "yaml"

# Built-in framework templates are data, not application rules. Add another
# entry to config/competency_framework_templates.yml to extend the library.
class CompetencyFrameworkTemplate
  PATH = Rails.root.join("config/competency_framework_templates.yml")

  attr_reader :key, :name, :description, :source_name, :source_version,
              :template_version, :attribution, :education_stage, :domains

  def initialize(key, attributes)
    @key = key.to_s
    @name = attributes.fetch("name")
    @description = attributes.fetch("description", "")
    @source_name = attributes.fetch("source_name")
    @source_version = attributes.fetch("source_version")
    @template_version = attributes.fetch("template_version")
    @attribution = attributes.fetch("attribution", "")
    @education_stage = attributes["education_stage"]
    @domains = attributes.fetch("domains", [])
  end

  def self.all
    data = YAML.safe_load_file(PATH, permitted_classes: [], aliases: false) || {}
    built_in = data.map { |key, attributes| new(key, attributes) }
    built_in + FrameworkTemplateRecord.order(:name).to_a
  end

  def self.find_by_key(key)
    key = key.to_s
    return FrameworkTemplateRecord.find_by(id: key.delete_prefix("custom-")) if key.start_with?("custom-")

    all.find { |template| template.key == key }
  end

  def custom? = false
end
