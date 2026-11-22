# frozen_string_literal: true

class ArtifactSubmissionReview < ApplicationRecord
  belongs_to :artifact_submission
  belongs_to :reviewer, class_name: "User"

  validates :decision, inclusion: { in: %w[approved rejected] }
  validates :notes, presence: true, length: { minimum: 10 }
  validates :reviewed_at, presence: true

  before_update { raise ActiveRecord::ReadOnlyRecord, "Riwayat telaah bersifat tetap." }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "Riwayat telaah tidak dapat dihapus." }
end
