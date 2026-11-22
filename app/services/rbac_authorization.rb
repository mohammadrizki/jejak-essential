# frozen_string_literal: true

# Role grants the capability; UserAssignment separately grants operational
# authority over a learner, rotation, dossier, or other assigned object.
class RbacAuthorization
  def self.allowed?(user:, permission:, study_program: nil)
    return false if user.blank?

    program = study_program || user.study_program
    grants = UserRole.includes(role: :role_permissions)
      .where(user_id: user.id).for_program(program)

    grants.any? do |grant|
      grant.role.role_permissions.any? do |role_permission|
        next false unless role_permission.system_permission.key == permission.to_s

        if grant.scope_level == "study_program"
          program.present? && grant.study_program_id == program.id
        elsif role_permission.scope_level == "system"
          true
        else
          program.present? && user.study_program_id == program.id
        end
      end
    end
  end

  # Global catalog permissions must be explicitly granted to a system-scoped
  # user role and at system scope. A program-scoped administrator cannot alter
  # shared templates merely because they can manage their local curriculum.
  def self.system_allowed?(user:, permission:)
    return false if user.blank?

    UserRole.includes(role: { role_permissions: :system_permission })
      .where(user_id: user.id, scope_level: "system", study_program_id: nil).any? do |grant|
        grant.role.role_permissions.any? do |role_permission|
          role_permission.scope_level == "system" && role_permission.system_permission.key == permission.to_s
        end
      end
  end
end
