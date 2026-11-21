# frozen_string_literal: true

class EvidenceRequirement < ApplicationRecord
  ORIGINS = %w[blueprint manual].freeze
  SOURCE_TYPES = %w[assessment logbook portfolio reflection epa_observation other].freeze
  SOURCE_TYPE_LABELS = {
    "assessment" => "Asesmen",
    "logbook" => "Logbook",
    "portfolio" => "Portofolio",
    "reflection" => "Refleksi",
    "epa_observation" => "Observasi EPA",
    "other" => "Lainnya"
  }.freeze
  RULE_KEYS = %w[
    require_validation valid_results minimum_valid_evidence minimum_pass
    minimum_distinct_cases minimum_distinct_assessors minimum_distinct_opportunities
    minimum_distinct_dates minimum_span_days
    minimum_attempts minimum_assessors require_distinct_cases
    independence_group critical additional_criteria
  ].freeze
  RULE_COUNT_KEYS = %w[
    minimum_valid_evidence minimum_pass minimum_distinct_cases
    minimum_distinct_assessors minimum_distinct_opportunities minimum_distinct_dates minimum_span_days
    minimum_attempts minimum_assessors
  ].freeze

  belongs_to :competency_item, optional: true
  belongs_to :competency_indicator, optional: true
  belongs_to :epa, optional: true
  belongs_to :blueprint_item, optional: true
  belongs_to :assessment_method, optional: true
  has_many :evidence_records, dependent: :restrict_with_error

  validates :origin, inclusion: { in: ORIGINS }
  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :status, inclusion: { in: %w[active inactive] }
  validates :required_count, numericality: { only_integer: true, greater_than: 0 }
  validate :valid_target_and_source
  validate :indicator_matches_competency
  validate :targets_share_framework
  validate :blueprint_target_is_mapped
  validate :manual_target_framework_is_draft
  validate :blueprint_source_is_draft
  validate :fulfillment_rule_is_valid
  before_validation :normalize_fulfillment_rule

  private

  def valid_target_and_source
    errors.add(:base, "target kompetensi atau EPA wajib diisi") if competency_item.blank? && epa.blank?
    errors.add(:blueprint_item, "wajib diisi untuk persyaratan blueprint") if origin == "blueprint" && blueprint_item.blank?
    errors.add(:blueprint_item, "harus kosong untuk persyaratan manual") if origin == "manual" && blueprint_item.present?
  end

  def indicator_matches_competency
    return if competency_indicator.blank? || competency_item.blank?
    return if competency_indicator.competency_item_id == competency_item_id

    errors.add(:competency_indicator, "harus merupakan indikator kompetensi yang dipilih")
  end

  def targets_share_framework
    target_framework_ids = [competency_item&.competency_framework_id, epa&.competency_framework_id].compact.uniq
    if blueprint_item.present?
      target_framework_ids << blueprint_item.blueprint_version.competency_framework_id
    end
    return if target_framework_ids.size <= 1

    errors.add(:base, "kompetensi, EPA, dan blueprint harus menggunakan framework yang sama")
  end

  def blueprint_target_is_mapped
    return if origin != "blueprint" || blueprint_item.blank?
    if competency_indicator.present? && !blueprint_item.blueprint_item_competencies.exists?(competency_indicator_id: competency_indicator_id)
      errors.add(:competency_indicator, "harus dipetakan ke komponen blueprint ini")
    elsif competency_item.present? && !blueprint_item.competency_items.exists?(id: competency_item_id)
      errors.add(:competency_item, "harus dipetakan ke komponen blueprint ini")
    end
  end

  def manual_target_framework_is_draft
    return unless origin == "manual"
    framework = competency_item&.competency_framework || epa&.competency_framework
    return if framework.blank? || framework.status == "draft"

    errors.add(:base, "Persyaratan manual hanya dapat diubah pada framework draf")
  end

  def blueprint_source_is_draft
    return if origin != "blueprint" || blueprint_item.blank?
    return if blueprint_item.blueprint_version.status == "draft"

    errors.add(:blueprint_item, "persyaratan hanya dapat diubah pada versi blueprint draf")
  end

  def normalize_fulfillment_rule
    rule = (fulfillment_rule || {}).to_h.deep_stringify_keys
    rule["require_validation"] = true unless rule.key?("require_validation")
    rule["require_validation"] = ActiveModel::Type::Boolean.new.cast(rule["require_validation"])
    rule["valid_results"] ||= EvidenceRecord::RESULTS - (rule["require_validation"] ? ["not_assessed"] : [])
    rule["independence_group"] = "indicator" if competency_indicator.present? && !rule.key?("independence_group")
    rule["independence_group"] ||= ""
    rule["critical"] = false unless rule.key?("critical")
    rule["critical"] = ActiveModel::Type::Boolean.new.cast(rule["critical"])
    if rule.key?("require_distinct_cases")
      rule["require_distinct_cases"] = ActiveModel::Type::Boolean.new.cast(rule["require_distinct_cases"])
    end
    rule["additional_criteria"] ||= ""
    RULE_COUNT_KEYS.each do |key|
      next unless rule[key].present?

      rule[key] = Integer(rule[key], exception: false) || rule[key]
    end
    self.fulfillment_rule = rule
  end

  def fulfillment_rule_is_valid
    rule = fulfillment_rule
    unless rule.is_a?(Hash)
      errors.add(:fulfillment_rule, "harus berupa aturan terstruktur")
      return
    end

    unknown_keys = rule.keys.map(&:to_s) - RULE_KEYS
    errors.add(:fulfillment_rule, "memuat aturan yang tidak dikenal: #{unknown_keys.join(', ')}") if unknown_keys.any?

    RULE_COUNT_KEYS.each do |key|
      next unless rule.key?(key) || rule.key?(key.to_sym)

      value = rule[key] || rule[key.to_sym]
      errors.add(:fulfillment_rule, "#{key} harus berupa bilangan bulat nol atau lebih") unless value.to_s.match?(/\A\d+\z/)
    end

    valid_results = rule["valid_results"] || rule[:valid_results]
    unless valid_results.is_a?(Array) && valid_results.present? && (valid_results - EvidenceRecord::RESULTS).empty?
      errors.add(:fulfillment_rule, "jenis hasil bukti yang valid tidak dikenal")
    end
    unless [true, false].include?(rule["require_validation"])
      errors.add(:fulfillment_rule, "require_validation harus berupa pilihan ya/tidak")
    end
    unless [true, false].include?(rule["critical"])
      errors.add(:fulfillment_rule, "critical harus berupa pilihan ya/tidak")
    end
    if rule.key?("require_distinct_cases") && ![true, false].include?(rule["require_distinct_cases"])
      errors.add(:fulfillment_rule, "require_distinct_cases harus berupa pilihan ya/tidak")
    end

    group = rule["independence_group"] || rule[:independence_group]
    errors.add(:fulfillment_rule, "kelompok independensi maksimal 100 karakter") if group.to_s.length > 100
    criteria = rule["additional_criteria"] || rule[:additional_criteria]
    errors.add(:fulfillment_rule, "ketentuan tambahan maksimal 1000 karakter") if criteria.to_s.length > 1000
  end
end
