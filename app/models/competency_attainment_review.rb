# frozen_string_literal: true

class CompetencyAttainmentReview < ApplicationRecord
  belongs_to :competency_attainment
  belongs_to :reviewer, class_name: "User"

  validates :decision, inclusion: { in: %w[approved rejected] }
  validates :notes, presence: true, length: { minimum: 10 }
  validates :reviewed_at, presence: true

  before_update { raise ActiveRecord::ReadOnlyRecord, "Riwayat keputusan bersifat tetap." }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "Riwayat keputusan tidak dapat dihapus." }
end
