# frozen_string_literal: true

# Immutable policy snapshot. A learner's evidence remains evaluated against
# the version that was in force when their first evidence was collected.
class EvidenceRequirementVersion < ApplicationRecord
  belongs_to :evidence_requirement
  has_many :evidence_records, dependent: :restrict_with_error

  validates :version, numericality: { only_integer: true, greater_than: 0 },
                      uniqueness: { scope: :evidence_requirement_id }
  validates :configuration, presence: true
  validate :configuration_is_a_supported_snapshot

  before_update { raise ActiveRecord::ReadOnlyRecord, "Versi Bukti yang Diharapkan bersifat tetap." }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "Versi Bukti yang Diharapkan tidak dapat dihapus." }

  def source_type = configuration.fetch("source_type")
  def fulfillment_rule = configuration.fetch("fulfillment_rule", {})
  def required_count = configuration.fetch("required_count").to_i
  def status = configuration.fetch("status")
  def indicator_id = configuration["competency_indicator_id"]
  def epa_id = configuration["epa_id"]

  private

  def configuration_is_a_supported_snapshot
    errors.add(:configuration, "harus berupa snapshot JSON") unless configuration.is_a?(Hash) &&
      configuration.key?("source_type") && configuration.key?("fulfillment_rule")
  end
end
