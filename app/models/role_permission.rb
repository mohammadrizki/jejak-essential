# frozen_string_literal: true

class RolePermission < ApplicationRecord
  belongs_to :role
  belongs_to :system_permission

  validates :scope_level, inclusion: { in: %w[system study_program] }
  validates :system_permission_id, uniqueness: { scope: :role_id }
  validate :global_template_permission_uses_system_scope

  private

  def global_template_permission_uses_system_scope
    return unless system_permission&.key == "templates.manage" && scope_level != "system"

    errors.add(:scope_level, "untuk kelola pustaka template harus mencakup sistem")
  end
end
