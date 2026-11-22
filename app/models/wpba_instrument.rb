# frozen_string_literal: true

class WpbaInstrument < ApplicationRecord
  WPBA_TYPES = %w[mini_cex cec cws bpe dops cbd msf].freeze
  # Legacy EPA type remains readable; EPA observations use their own workflow.
  TYPES = (WPBA_TYPES + %w[epa_observation other]).freeze
  CREATABLE_TYPES = (WPBA_TYPES + %w[other]).freeze

  has_many :versions, class_name: "WpbaInstrumentVersion", dependent: :restrict_with_error

  validates :code, :name, presence: true
  validates :code, uniqueness: true
  validates :instrument_type, inclusion: { in: TYPES }

  scope :active, -> { where(active: true).where.not(instrument_type: "epa_observation").order(:name) }

  def current_version
    versions.where.not(published_at: nil).order(published_at: :desc, id: :desc).first ||
      versions.order(created_at: :desc, id: :desc).first
  end

  def wpba_method?
    instrument_type.in?(WPBA_TYPES)
  end
end
