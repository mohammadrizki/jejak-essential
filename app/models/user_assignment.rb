# frozen_string_literal: true

class UserAssignment < ApplicationRecord
  ROLES = %w[
    artifact_reviewer epa_observer epa_panel_member epa_panel_chair epa_ad_hoc_decider wpba_assessor logbook_verifier clinical_case_verifier
    competency_attainment_proposer competency_attainment_decider external_data_manager evidence_reviewer
  ].freeze

  belongs_to :user
  belongs_to :assigned_by, class_name: "User"
  belongs_to :revoked_by, class_name: "User", optional: true
  belongs_to :study_program, optional: true

  validates :assignment_role, inclusion: { in: ROLES }
  validates :scope_type, inclusion: { in: %w[User StudyProgram EpaPromotion ClinicalRotation] }, allow_nil: true
  validate :scope_presence_and_ownership
  validate :scope_matches_assignment_role
  validate :scope_target_is_valid
  validate :assignee_role_is_eligible

  scope :active, -> { where(revoked_at: nil).where("starts_on IS NULL OR starts_on <= ?", Date.current)
    .where("ends_on IS NULL OR ends_on >= ?", Date.current) }

  def revoke!(by:, reason:)
    raise ArgumentError, "Alasan pencabutan minimal 10 karakter." if reason.to_s.strip.length < 10
    raise ArgumentError, "Penugasan sudah dicabut." if revoked_at.present?

    update!(revoked_at: Time.current, revoked_by: by,
      reason: [self.reason, "Dicabut oleh #{by.id}: #{reason.to_s.strip}"].compact.join(" | "))
  end

  def matches?(role:, student:, object: nil)
    return false unless assignment_role == role && revoked_at.nil?
    return false if starts_on.present? && starts_on > Date.current
    return false if ends_on.present? && ends_on < Date.current
    return false if study_program_id.present? && study_program_id != student.study_program_id
    return false if scope_type == "StudyProgram" && scope_id != student.study_program_id
    return false if scope_type == "User" && scope_id != student.id
    return false if scope_type == "EpaPromotion" && !matches_promotion_scope?(object)
    if scope_type == "ClinicalRotation"
      rotation = rotation_for(object)
      return false if rotation.blank? || rotation.id != scope_id || rotation.user_id != student.id
    end

    true
  end

  private

  # A dossier-specific appointment continues only to a renewal dossier that
  # explicitly references a decision from the appointed dossier. This keeps
  # the renewal panel continuous without broadening unrelated assignments.
  def matches_promotion_scope?(object)
    return false unless object.is_a?(EpaPromotion)
    return true if scope_id == object.id

    object.renewal_of_decision&.epa_promotion_id == scope_id
  end

  def rotation_for(object)
    return object if object.is_a?(ClinicalRotation)
    return object.clinical_rotation if object.respond_to?(:clinical_rotation)
    if object.is_a?(EvidenceRecord)
      local_source = object.activity_log || object.reflection_entry&.activity_log || object.epa_observation ||
        object.mini_cex_evaluation || object.dops_evaluation
      return local_source.clinical_rotation if local_source.respond_to?(:clinical_rotation)
      return ClinicalRotation.find_by(id: object.evidence_source&.context&.fetch("rotation_id", nil))
    end
    return ClinicalRotation.find_by(id: object.context.to_h["rotation_id"]) if object.is_a?(EvidenceSource)

    nil
  end

  def scope_presence_and_ownership
    return if scope_type.blank? == scope_id.blank?

    errors.add(:scope_id, "jenis dan ID lingkup tugas harus diisi bersama")
  end

  def scope_matches_assignment_role
    return if scope_type.blank? || assignment_role.blank?

    allowed = case assignment_role
    when "artifact_reviewer", "epa_observer", "logbook_verifier", "clinical_case_verifier", "evidence_reviewer" then %w[User StudyProgram ClinicalRotation]
    when "epa_panel_member", "epa_panel_chair" then %w[User StudyProgram EpaPromotion]
    when "epa_ad_hoc_decider" then %w[User StudyProgram ClinicalRotation]
    when "wpba_assessor" then %w[User StudyProgram ClinicalRotation]
    when "competency_attainment_proposer", "competency_attainment_decider" then %w[User StudyProgram]
    when "external_data_manager" then %w[StudyProgram]
    else []
    end
    return if allowed.include?(scope_type)

    errors.add(:scope_type, "tidak sesuai dengan jenis penugasan")
  end

  def scope_target_is_valid
    return if scope_type.blank? || scope_id.blank?

    valid = case scope_type
    when "User"
      target = User.find_by(id: scope_id)
      target&.has_role?("mahasiswa") && (study_program_id.blank? || target.study_program_id == study_program_id)
    when "StudyProgram"
      StudyProgram.exists?(id: scope_id) && (study_program_id.blank? || scope_id == study_program_id)
    when "EpaPromotion"
      promotion = EpaPromotion.includes(:student).find_by(id: scope_id)
      promotion.present? && (study_program_id.blank? || promotion.student.study_program_id == study_program_id)
    when "ClinicalRotation"
      rotation = ClinicalRotation.includes(:user).find_by(id: scope_id)
      rotation.present? && (study_program_id.blank? || rotation.user.study_program_id == study_program_id)
    end
    errors.add(:scope_id, "tidak menunjuk ke objek dalam lingkup program studi") unless valid
  end

  def assignee_role_is_eligible
    return if user.blank? || assignment_role.blank?
    return if user.has_role?("admin")
    return if %w[artifact_reviewer epa_observer epa_panel_member epa_panel_chair epa_ad_hoc_decider competency_attainment_decider].include?(assignment_role) &&
      (user.has_role?("dosen") || user.has_role?("kaprodi") || user.has_role?("preseptor"))
    return if assignment_role == "evidence_reviewer" &&
      (user.has_role?("dosen") || user.has_role?("kaprodi") || user.has_role?("preseptor"))
    return if assignment_role == "competency_attainment_proposer" &&
      (user.has_role?("dosen") || user.has_role?("preseptor"))
    return if %w[wpba_assessor logbook_verifier clinical_case_verifier evidence_reviewer].include?(assignment_role) &&
      (user.has_role?("dosen") || user.has_role?("preseptor"))
    return if assignment_role == "external_data_manager" && user.has_role?("tenaga_kependidikan")

    errors.add(:user, "tidak memiliki peran yang sesuai untuk jenis penugasan ini")
  end
end
