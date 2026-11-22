# frozen_string_literal: true

class ExternalMappingEvent < ApplicationRecord
  belongs_to :external_identity_mapping
  belongs_to :changed_by, class_name: "User"

  validates :previous_internal_record_id, :new_internal_record_id, :reason, :changed_at, presence: true
  validates :reason, length: { minimum: 10 }

  before_update { raise ActiveRecord::ReadOnlyRecord, "Riwayat pemetaan bersifat tetap." }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "Riwayat pemetaan tidak dapat dihapus." }
end
