# frozen_string_literal: true

class ModuleConfigurationChange < ApplicationRecord
  belongs_to :study_program
  belongs_to :actor, class_name: "User"

  validates :before_value, :after_value, presence: true
  before_update :prevent_mutation
  before_destroy :prevent_mutation

  private

  def prevent_mutation
    errors.add(:base, "Riwayat konfigurasi modul tidak dapat diubah atau dihapus")
    throw :abort
  end
end
