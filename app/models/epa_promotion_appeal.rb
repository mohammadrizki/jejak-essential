# frozen_string_literal: true

class EpaPromotionAppeal < ApplicationRecord
  RESOLUTIONS = %w[approved restricted needs_more_evidence not_entrusted deferred revoked].freeze

  belongs_to :epa_promotion
  belongs_to :appealed_by, class_name: "User"
  belongs_to :resolved_by, class_name: "User", optional: true

  validates :round_number, numericality: { only_integer: true, greater_than: 1 }
  validates :reason, presence: true, length: { minimum: 10 }
  validates :resolution, inclusion: { in: RESOLUTIONS }, allow_nil: true
  validate :resolution_fields_are_consistent
  before_update :only_allow_single_resolution
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "Riwayat keberatan tidak dapat dihapus." }

  def resolve!(by:, resolution:, notes:)
    raise ArgumentError, "Keberatan sudah diputus." if resolved_at.present?
    update!(resolved_by: by, resolution: resolution, resolution_notes: notes.to_s.strip, resolved_at: Time.current)
  end

  private

  def resolution_fields_are_consistent
    resolved = resolution.present? || resolved_by_id.present? || resolved_at.present?
    return unless resolved

    errors.add(:resolution, "wajib mencatat hasil, pemutus, dan waktu secara lengkap") if
      resolution.blank? || resolved_by.blank? || resolved_at.blank? || resolution_notes.to_s.strip.length < 10
  end

  def only_allow_single_resolution
    return if resolution_in_database.nil? && resolution.present? &&
      (changes_to_save.keys - %w[resolution resolution_notes resolved_by_id resolved_at updated_at]).empty?

    errors.add(:base, "Riwayat keberatan hanya dapat diselesaikan satu kali")
    throw :abort
  end
end
