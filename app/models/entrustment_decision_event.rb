# frozen_string_literal: true

class EntrustmentDecisionEvent < ApplicationRecord
  EVENT_TYPES = %w[issued restricted renewed revoked expired corrected superseded].freeze

  belongs_to :entrustment_decision
  belongs_to :actor, class_name: "User", optional: true

  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :occurred_at, presence: true
  before_update :prevent_mutation
  before_destroy :prevent_deletion

  private

  def prevent_mutation
    errors.add(:base, "Riwayat keputusan entrustment tidak dapat diubah")
    throw :abort
  end

  def prevent_deletion
    errors.add(:base, "Riwayat keputusan entrustment tidak dapat dihapus")
    throw :abort
  end
end
