# frozen_string_literal: true

class EpaObservation < ApplicationRecord
  STATUSES = %w[draft submitted recorded returned voided].freeze
  COMPLEXITIES = %w[routine moderate complex critical].freeze

  belongs_to :student, class_name: "User"
  belongs_to :epa
  belongs_to :observer, class_name: "User"
  belongs_to :clinical_case, optional: true
  belongs_to :clinical_rotation, optional: true
  belongs_to :supervision_level
  belongs_to :safety_resolved_by, class_name: "User", optional: true
  has_many :evidence_records, dependent: :restrict_with_error

  validates :observed_at, :narrative, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :complexity, inclusion: { in: COMPLEXITIES }
  validate :observation_not_in_future
  validate :epa_applicable_to_student
  validate :retrospective_scale_required
  validate :case_belongs_to_student
  validate :rotation_matches_student
  validate :submitted_observations_are_immutable, on: :update
  after_commit :refresh_promotion_readiness, on: %i[create update]

  scope :usable_as_evidence, -> { where(status: "recorded").where("safety_flag = FALSE OR safety_resolved_at IS NOT NULL") }
  scope :chronological, -> { order(observed_at: :desc, id: :desc) }

  def submit!
    update!(status: "submitted", submitted_at: Time.current)
  end

  def record!
    update!(status: "recorded")
  end

  def resolve_safety!(by:, resolution:)
    update!(safety_resolution: resolution, safety_resolved_at: Time.current, safety_resolved_by: by)
  end

  private

  def epa_applicable_to_student
    framework = epa&.competency_framework
    return if framework.blank? || student.blank?
    return if framework.study_program_id == student.study_program_id &&
              framework.education_stage.in?(%w[professional specialist subspecialist]) &&
              framework.status == "published" && epa.status == "published"

    errors.add(:epa, "EPA harus berasal dari framework jenjang Profesi, Spesialis, atau Subspesialis mahasiswa")
  end

  def retrospective_scale_required
    return if supervision_level.blank?
    return if supervision_level.supervision_scale_version.use_case == "retrospective_observation"

    errors.add(:supervision_level, "observasi harus menggunakan skala supervisi retrospektif")
  end

  def case_belongs_to_student
    return if clinical_case.blank? || clinical_case.user_id == student_id

    errors.add(:clinical_case, "harus merupakan kasus milik mahasiswa yang diamati")
  end

  def rotation_matches_student
    return if clinical_rotation.blank? || clinical_rotation.user_id == student_id

    errors.add(:clinical_rotation, "harus merupakan rotasi mahasiswa yang diamati")
  end

  def observation_not_in_future
    errors.add(:observed_at, "tidak boleh berada di masa depan") if observed_at.present? && observed_at > Time.current
  end

  def submitted_observations_are_immutable
    return if status_in_database == "draft"
    return if (changes_to_save.keys - %w[status]).empty? && status.in?(%w[recorded returned voided])
    return if safety_resolved_at_in_database.nil? &&
              changes_to_save.keys.sort == %w[safety_resolution safety_resolved_at safety_resolved_by_id] &&
              status == status_in_database && safety_flag && safety_resolution.to_s.strip.length >= 10

    errors.add(:base, "observasi yang sudah dikirim hanya dapat dikoreksi melalui catatan baru")
  end

  def refresh_promotion_readiness
    return unless status == "recorded"

    epa.evidence_requirements.where(status: "active", source_type: "epa_observation").find_each do |requirement|
      EvidenceRecord.find_or_create_by!(evidence_requirement: requirement, epa_observation: self) do |record|
        record.evidence_date = observed_at.to_date
        record.result = "other"
      end
    end
    refresh_canonical_evidence_source!
    EpaPromotionReadiness.new(student: student, epa: epa).promote_if_eligible!
  end

  # Safety resolution changes the validity of an existing observation. Keep
  # the prior source revision for audit, and point requirement links at the
  # new canonical snapshot so readiness reflects the resolution.
  def refresh_canonical_evidence_source!
    source = EvidenceSource.for_local_record!(self)
    evidence_records.update_all(evidence_source_id: source.id, updated_at: Time.current)
  end
end
