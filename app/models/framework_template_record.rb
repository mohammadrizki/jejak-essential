# frozen_string_literal: true

class FrameworkTemplateRecord < ApplicationRecord
  attr_accessor :domains_json

  belongs_to :created_by, class_name: "User", optional: true

  validates :name, :source_name, :source_version, :template_version, presence: true
  validates :education_stage, inclusion: { in: StudyProgram::LEVELS.keys }, allow_blank: true
  validate :domains_have_supported_structure

  def key = "custom-#{id}"
  def custom? = true

  private

  def domains_have_supported_structure
    unless domains.is_a?(Array)
      errors.add(:domains, "harus berupa daftar domain dalam format JSON")
      return
    end

    codes = []
    domains.each_with_index do |domain, index|
      unless domain.is_a?(Hash) && domain["code"].present? && domain["title"].present?
        errors.add(:domains, "domain ke-#{index + 1} wajib memiliki code dan title")
        next
      end
      codes << domain["code"]
      indicators = domain["indicators"] || []
      subs = domain["subcompetencies"] || []
      unless indicators.is_a?(Array) && subs.is_a?(Array)
        errors.add(:domains, "indikator dan subkompetensi harus berupa daftar")
        next
      end
      validate_indicator_list(indicators)
      codes.concat(indicators.filter_map { |entry| entry["code"] if entry.is_a?(Hash) })
      subs.each do |sub|
        unless sub.is_a?(Hash) && sub["code"].present? && sub["title"].present? && sub.fetch("indicators", []).is_a?(Array)
          errors.add(:domains, "subkompetensi wajib memiliki code, title, dan daftar indicators")
          next
        end
        codes << sub["code"]
        validate_indicator_list(sub["indicators"])
        codes.concat(sub["indicators"].filter_map { |entry| entry["code"] if entry.is_a?(Hash) })
      end
    end
    errors.add(:domains, "kode domain, subkompetensi, dan indikator harus unik dalam template") unless codes.uniq.size == codes.size
  end

  def validate_indicator_list(indicators)
    indicators.each do |indicator|
      next if indicator.is_a?(Hash) && indicator["code"].present? && indicator["description"].present? && indicator["performance_level"].present?

      errors.add(:domains, "setiap indikator wajib memiliki code, description, dan performance_level")
    end
  end
end
