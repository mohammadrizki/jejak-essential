# frozen_string_literal: true

class UserRole < ApplicationRecord
  belongs_to :user
  belongs_to :role
  belongs_to :study_program, optional: true

  validates :scope_level, inclusion: { in: %w[system study_program unassigned] }
  validates :study_program, presence: true, if: -> { scope_level == "study_program" }
  validates :study_program, absence: true, if: -> { %w[system unassigned].include?(scope_level) }
  validate :only_superadmin_can_receive_system_scope
  validate :superadmin_must_be_system_scoped

  scope :for_program, ->(program) { where(scope_level: "system").or(where(scope_level: "study_program", study_program: program)) }

  def allows_program?(program)
    scope_level == "system" || (scope_level == "study_program" && study_program_id == program&.id)
  end

  private

  def only_superadmin_can_receive_system_scope
    return unless scope_level == "system" && role&.code == "admin"
    return if user&.user_roles&.joins(:role)&.where(roles: { code: "superadmin" }, scope_level: "system")&.exists?

    errors.add(:scope_level, "admin sistem hanya dapat diberikan melalui bootstrap superadmin")
  end

  def superadmin_must_be_system_scoped
    return unless role&.code == "superadmin" && scope_level != "system"

    errors.add(:scope_level, "superadmin harus memiliki cakupan sistem")
  end
end
