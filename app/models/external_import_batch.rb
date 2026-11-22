# frozen_string_literal: true

class ExternalImportBatch < ApplicationRecord
  SOURCE_SYSTEMS = %w[moodle examtool osce clinical_wpba].freeze
  STATUSES = %w[previewed imported failed].freeze

  belongs_to :study_program
  belongs_to :uploaded_by, class_name: "User"

  validates :source_system, inclusion: { in: SOURCE_SYSTEMS }
  validates :filename, :file_sha256, presence: true
  validates :file_sha256, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :status, inclusion: { in: STATUSES }
  validates :row_count, :imported_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :row_results_are_structured
  before_update :prevent_completed_batch_mutation
  before_destroy :prevent_deletion

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  def imported? = status == "imported"
  def failed? = status == "failed"
  def previewed? = status == "previewed"

  def complete!(row_results:, imported_count:)
    raise ArgumentError, "Batch impor sudah diselesaikan." unless previewed?

    update!(status: "imported", row_results: row_results, imported_count: imported_count,
      completed_at: Time.current)
  end

  def fail!(row_results:)
    raise ArgumentError, "Batch impor sudah diselesaikan." unless previewed?

    update!(status: "failed", row_results: row_results, completed_at: Time.current)
  end

  private

  def row_results_are_structured
    errors.add(:row_results, "harus berupa daftar hasil per baris") unless row_results.is_a?(Array)
  end

  def prevent_completed_batch_mutation
    previous_status = status_in_database
    permitted_transition = previous_status == "previewed" && status.in?(%w[imported failed]) &&
      completed_at.present? && will_save_change_to_status? && will_save_change_to_row_results?
    return if permitted_transition

    errors.add(:base, "Riwayat impor hanya dapat berpindah satu kali dari pratinjau ke hasil akhir")
    throw :abort
  end

  def prevent_deletion
    errors.add(:base, "Riwayat impor eksternal tidak dapat dihapus")
    throw :abort
  end
end
