# frozen_string_literal: true

class WpbaInstrumentVersion < ApplicationRecord
  belongs_to :wpba_instrument
  belongs_to :published_by, class_name: "User", optional: true
  has_many :mini_cex_evaluations, dependent: :restrict_with_error
  has_many :dops_evaluations, dependent: :restrict_with_error
  has_many :assessment_events, dependent: :restrict_with_error
  has_many :wpba_observations, dependent: :restrict_with_error

  validates :version_label, presence: true
  validates :version_label, uniqueness: { scope: :wpba_instrument_id }
  validates :definition, presence: true
  validate :published_definition_is_immutable, on: :update
  validate :custom_component_definition_is_valid

  def components
    Array(definition.to_h["components"])
  end

  def component_response_label(component, value)
    return if value.blank?

    levels = component.to_h.deep_stringify_keys["levels"].to_h
    raw_descriptor = levels[value.to_s]
    descriptor = raw_descriptor.is_a?(Hash) ? raw_descriptor.deep_stringify_keys : { "label" => raw_descriptor }
    descriptor["label"].presence || value
  end

  def component_response_description(component, value)
    raw_descriptor = component.to_h.deep_stringify_keys.dig("levels", value.to_s)
    raw_descriptor.to_h.deep_stringify_keys["description"] if raw_descriptor.is_a?(Hash)
  end

  def publish!(by:)
    update!(published_at: Time.current, published_by: by)
  end

  private

  def published_definition_is_immutable
    return if published_at_in_database.nil?
    return if (changes_to_save.keys - %w[updated_at]).empty?

    errors.add(:base, "Versi instrumen yang sudah diterbitkan tidak dapat diubah; buat versi baru.")
  end

  def custom_component_definition_is_valid
    return unless wpba_instrument&.instrument_type == "other"

    entries = definition.to_h["components"]
    unless entries.is_a?(Array) && entries.present? && entries.size <= 30
      errors.add(:definition, "instrumen khusus harus memiliki 1–30 komponen")
      return
    end

    keys = []
    entries.each_with_index do |raw, index|
      component = raw.to_h.deep_stringify_keys
      key = component["key"].to_s
      label = component["label"].to_s.strip
      type = component["type"].to_s
      errors.add(:definition, "komponen #{index + 1} memerlukan key unik berupa snake_case") unless
        key.match?(/\A[a-z][a-z0-9_]{0,59}\z/) && keys.exclude?(key)
      keys << key
      errors.add(:definition, "komponen #{index + 1} memerlukan label maksimal 120 karakter") if label.blank? || label.length > 120
      errors.add(:definition, "tipe komponen #{index + 1} harus rating, text, select, atau boolean") unless
        type.in?(%w[rating text select boolean])

      if type == "rating"
        min = Integer(component["minimum"], exception: false)
        max = Integer(component["maximum"], exception: false)
        errors.add(:definition, "rentang komponen #{index + 1} harus bilangan bulat dan maksimum lebih besar") unless
          min && max && min < max && min >= 0 && max <= 100
        validate_rating_levels(component["levels"], min, max, index) if component.key?("levels") && min && max && min < max
      elsif type == "select"
        options = component["options"]
        valid_options = options.is_a?(Array) && options.size.between?(2, 30) &&
          options.all? { |option| option.is_a?(String) && option.strip.present? && option.length <= 120 } &&
          options.uniq.size == options.size
        errors.add(:definition, "komponen select #{index + 1} harus punya 2–30 opsi unik") unless valid_options
      end

      if component.key?("required") && ![ true, false ].include?(component["required"])
        errors.add(:definition, "required pada komponen #{index + 1} harus boolean")
      end
    end
  end

  def validate_rating_levels(levels, minimum, maximum, index)
    expected_scores = (minimum..maximum).map(&:to_s)
    unless levels.is_a?(Hash) && levels.keys.map(&:to_s).sort == expected_scores.sort
      errors.add(:definition, "jangkar rating komponen #{index + 1} harus mendefinisikan setiap nilai #{minimum}–#{maximum}")
      return
    end

    levels.each do |score, raw_descriptor|
      descriptor = raw_descriptor.is_a?(Hash) ? raw_descriptor.deep_stringify_keys : { "label" => raw_descriptor }
      label = descriptor["label"].to_s.strip
      description = descriptor["description"].to_s
      unless label.present? && label.length <= 120 && description.length <= 300
        errors.add(:definition, "jangkar rating #{score} komponen #{index + 1} memerlukan label (maks. 120) dan deskripsi (maks. 300) karakter")
      end
    end
  end
end
