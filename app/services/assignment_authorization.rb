# frozen_string_literal: true

class AssignmentAuthorization
  def self.assigned?(user:, role:, student:, object: nil)
    return false if user.blank? || student.blank?
    return false unless user.has_permission?(permission_for(role), study_program: student.study_program)
    return true if built_in_assignment?(user, role, student, object)

    UserAssignment.active.where(user: user, assignment_role: role).any? do |assignment|
      assignment.matches?(role: role, student: student, object: object)
    end
  end

  def self.permission_for(role)
    case role.to_s
    when "competency_attainment_decider" then "assessment.decide"
    when "epa_panel_member", "epa_panel_chair", "epa_ad_hoc_decider" then "epa.decide"
    when "external_data_manager" then "integration.manage"
    else "assessment.review"
    end
  end
  private_class_method :permission_for

  def self.panel_member_ids(student:, promotion:)
    ids = []
    UserAssignment.active.where(assignment_role: "epa_panel_member").find_each do |assignment|
      authorized = assignment.user.has_permission?("epa.decide", study_program: student.study_program)
      ids << assignment.user_id if authorized && assignment.matches?(role: "epa_panel_member", student: student, object: promotion)
    end
    ids.uniq
  end

  def self.grant!(user:, role:, by:, study_program: nil, scope: nil, starts_on: nil, ends_on: nil, reason: nil)
    raise ArgumentError, "Hak akses mengelola assignment pada program studi ini diperlukan." unless by.has_role?("superadmin") ||
      (study_program.present? && by.has_permission?("assignments.manage", study_program: study_program))

    UserAssignment.create!(user: user, assigned_by: by, assignment_role: role,
      study_program: study_program, scope_type: scope&.class&.name,
      scope_id: scope&.id, starts_on: starts_on, ends_on: ends_on, reason: reason)
  end

  def self.built_in_assignment?(user, role, student, object)
    case role
    when "competency_attainment_decider"
      user.has_role?("kaprodi") && user.study_program_id.present? && user.study_program_id == student.study_program_id
    when "competency_attainment_proposer"
      (user.has_role?("dosen") || user.has_role?("preseptor")) &&
        user.id != student.id && student.supervised_by?(user)
    when "wpba_assessor"
      object.is_a?(ClinicalRotation) && object.user_id == student.id && object.preceptor_id == user.id &&
        (user.has_role?("dosen") || user.has_role?("preseptor"))
    else
      false
    end
  end
  private_class_method :built_in_assignment?
end
