# frozen_string_literal: true

class EpaPromotion < ApplicationRecord
  STATUSES = %w[ready promoted under_review needs_more_evidence not_entrusted approved restricted deferred revoked appeal_pending].freeze
  OPEN_STATUSES = %w[ready promoted under_review appeal_pending].freeze

  belongs_to :student, class_name: "User"
  belongs_to :epa
  belongs_to :promoted_by, class_name: "User", optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true
  belongs_to :finalized_by, class_name: "User", optional: true
  belongs_to :renewal_of_decision, class_name: "EntrustmentDecision", optional: true
  has_many :entrustment_decisions, dependent: :restrict_with_error
  has_many :epa_promotion_reviews, dependent: :restrict_with_error
  has_many :epa_promotion_appeals, dependent: :restrict_with_error

  validates :status, inclusion: { in: STATUSES }
  validates :eligible_at, presence: true
  validate :appeal_reason_required
  validate :epa_matches_student
  validate :renewal_decision_matches
  before_update :prevent_renewal_reference_change

  scope :open, -> { where(status: OPEN_STATUSES) }

  def promote!(by:)
    snapshot = CompetencyAttainmentSnapshot.capture_epa_dossier(student: student, epa: epa)
    update!(status: "promoted", promoted_by: by, promoted_at: Time.current,
      dossier_snapshot: snapshot, quorum_reached_at: nil, finalized_at: nil, finalized_by: nil)
  end

  def self.request_renewal!(decision:, by:)
    transaction do
      decision.lock!
      raise ArgumentError, "Keputusan EPA tidak lagi aktif." unless decision.superseded_at.nil?
      raise ArgumentError, "Tanggal tinjauan ulang belum jatuh tempo." unless decision.review_due?
      raise ArgumentError, "Tinjauan ulang EPA ini sudah memiliki dossier terbuka." if open.exists?(student: decision.student, epa: decision.epa)

      create!(student: decision.student, epa: decision.epa, renewal_of_decision: decision,
        status: "promoted", eligible_at: Time.current, promoted_by: by, promoted_at: Time.current,
        dossier_snapshot: CompetencyAttainmentSnapshot.capture_epa_dossier(student: decision.student, epa: decision.epa),
        notes: "Tinjauan ulang keputusan entrustment #{decision.id} yang telah mencapai tanggal review.")
    end
  end

  def appeal!(reason:)
    reason = reason.to_s.strip
    raise ArgumentError, "Alasan keberatan minimal 10 karakter." if reason.length < 10
    raise ArgumentError, "Keputusan ini belum dapat diajukan keberatan." unless status.in?(%w[approved restricted not_entrusted deferred])

    self.class.transaction do
      next_round = review_round + 1
      epa_promotion_appeals.create!(appealed_by: student, round_number: next_round, reason: reason)
      update!(status: "appeal_pending", appealed_at: Time.current, appeal_reason: reason,
        quorum_reached_at: nil, finalized_at: nil, finalized_by: nil, review_round: next_round)
    end
  end

  private

  def epa_matches_student
    return if epa.blank? || student.blank?
    return if epa.competency_framework.study_program_id == student.study_program_id &&
              epa.competency_framework.education_stage.in?(%w[undergraduate professional specialist subspecialist]) &&
              ModuleConfiguration.for(student.study_program).enabled?("epa") &&
              epa.competency_framework.status == "published" && epa.status == "published"

    errors.add(:epa, "EPA tidak berlaku bagi program studi mahasiswa")
  end

  def appeal_reason_required
    errors.add(:appeal_reason, "wajib diisi untuk keberatan") if status == "appeal_pending" && appeal_reason.to_s.strip.length < 10
  end

  def renewal_decision_matches
    return if renewal_of_decision.blank?
    return if persisted? || (renewal_of_decision.student_id == student_id && renewal_of_decision.epa_id == epa_id &&
      renewal_of_decision.superseded_at.nil? && renewal_of_decision.review_due?)

    errors.add(:renewal_of_decision, "harus merupakan keputusan aktif EPA ini yang tanggal tinjauannya telah jatuh tempo")
  end

  def prevent_renewal_reference_change
    return unless will_save_change_to_renewal_of_decision_id?

    errors.add(:renewal_of_decision, "referensi keputusan tinjauan ulang tidak dapat diubah")
    throw :abort
  end
end
