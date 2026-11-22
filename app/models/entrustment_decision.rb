# frozen_string_literal: true

# Tingkat entrustment EPA 1–5 per mahasiswa × ranah
# kompetensi/EPA. Setiap keputusan baru MENGGANTIKAN (supersede) yang lama —
# riwayat tetap tersimpan untuk audit. competency_item_id tetap ada untuk
# kompatibilitas portofolio lama; epa_id mengidentifikasi aktivitas eksplisit.
class EntrustmentDecision < ApplicationRecord
  LEVELS = {
    1 => "Hanya mengamati, tidak boleh terlibat",
    2 => "Boleh terlibat dengan supervisi penuh",
    3 => "Bisa mandiri dengan supervisi tidak langsung",
    4 => "Mandiri penuh",
    5 => "Mampu mengajarkan dan mensupervisi junior"
  }.freeze

  # Pemetaan 6 level entrustment verifikasi kasus (ClinicalCase) → skala 1–5.
  CASE_LEVEL_MAP = {
    "diobservasi" => 1, "dibantu" => 2, "supervisi_langsung" => 2,
    "supervisi_tidak_langsung" => 3, "mandiri" => 4, "mengajari_junior" => 5
  }.freeze

  MIN_JUSTIFICATION = 10
  DECISION_KINDS = %w[legacy ad_hoc summative].freeze
  DECISION_STATUSES = %w[active restricted expired revoked superseded].freeze

  belongs_to :student, class_name: "User"
  belongs_to :competency_item, optional: true
  belongs_to :epa, optional: true
  belongs_to :decided_by, class_name: "User"
  belongs_to :clinical_case, optional: true
  belongs_to :superseded_by, class_name: "EntrustmentDecision", optional: true
  belongs_to :supervision_level, optional: true
  belongs_to :epa_promotion, optional: true
  has_many :renewal_promotions, class_name: "EpaPromotion", foreign_key: :renewal_of_decision_id,
    dependent: :restrict_with_error
  belongs_to :revoked_by, class_name: "User", optional: true
  belongs_to :revocation_epa_promotion, class_name: "EpaPromotion", optional: true
  has_many :events, class_name: "EntrustmentDecisionEvent", dependent: :restrict_with_error

  validates :justification, presence: true, length: { minimum: MIN_JUSTIFICATION, message: "minimal #{MIN_JUSTIFICATION} karakter" }
  validates :decision_kind, inclusion: { in: DECISION_KINDS }
  validates :decision_status, inclusion: { in: DECISION_STATUSES }
  validates :activity_description, presence: true, if: -> { decision_kind == "ad_hoc" && epa.blank? }
  validates :valid_until, comparison: { greater_than: :valid_from }, if: -> { valid_until.present? && valid_from.present? }
  before_validation :assign_legacy_epa, if: -> { epa_id.nil? }
  before_validation :assign_lifecycle_defaults
  validate :epa_matches_competency
  validate :supervision_level_matches_decision
  validate :promotion_matches_decision
  validate :decision_dossier_kind_matches
  validate :revocation_is_audited
  validate :finalized_decision_is_immutable, on: :update

  scope :current, -> { where(decision_status: %w[active restricted], superseded_at: nil)
    .where("valid_from <= ? AND (valid_until IS NULL OR valid_until > ?)", Time.current, Time.current) }
  scope :history, -> { order(created_at: :desc) }

  def level_label = supervision_level&.label || LEVELS[level]

  def review_due?
    review_due_at.present? && review_due_at <= Time.current
  end

  def epa_title = epa&.title || competency_item&.title || activity_description

  # Membuat keputusan baru dan menandai keputusan lama (mahasiswa × ranah
  # yang sama) sebagai tergantikan — atomik.
  def self.decide!(student:, competency_item: nil, epa: nil, level:, justification:, decided_by:, clinical_case: nil,
                   supervision_level: nil, epa_promotion: nil, review_due_at: nil, decision_kind: nil,
                   activity_description: nil, scope_limitations: nil, context: {}, valid_from: Time.current, valid_until: nil)
    transaction do
      epa ||= legacy_epa_for(competency_item)
      # Keep the pre-lifecycle API compatible for old callers. New ad hoc
      # decisions must opt in explicitly and provide a versioned scale.
      kind = decision_kind || (epa_promotion.present? ? "summative" : "legacy")
      raise ArgumentError, "Keputusan sumatif harus melalui dossier Otoritas Akademik." if kind == "summative" && epa_promotion.blank?
      raise ArgumentError, "Keputusan ad hoc tidak boleh menimpa keputusan panel." if kind == "ad_hoc" && epa_promotion.present?

      prior = if kind.in?(%w[summative legacy])
        current.where(student: student, epa: epa, decision_kind: kind).to_a
      else
        []
      end
      decision = create!(student: student, competency_item: competency_item, epa: epa, level: level,
                         justification: justification, decided_by: decided_by, clinical_case: clinical_case,
                         supervision_level: supervision_level, epa_promotion: epa_promotion,
                         review_due_at: review_due_at, decision_kind: kind,
                         decision_status: epa_promotion&.status == "restricted" ? "restricted" : "active",
                         activity_description: activity_description, scope_limitations: scope_limitations,
                         context: context, valid_from: valid_from, valid_until: valid_until)
      prior.each do |old|
        before_state = old.lifecycle_snapshot
        old.with_lifecycle_transition do
          old.update!(superseded_by: decision, superseded_at: Time.current, decision_status: "superseded")
        end
        old.record_event!("superseded", by: decided_by, reason: "Digantikan oleh keputusan #{decision.id}.",
          before_state: before_state)
      end
      decision.record_event!(decision.decision_status == "restricted" ? "restricted" : "issued", by: decided_by,
        reason: justification, after_state: decision.lifecycle_snapshot)
      decision
    end
  end

  # Verifikasi kasus dibatalkan: keputusan TERKINI yang lahir dari kasus itu
  # dicabut (superseded_at tanpa superseded_by = dicabut, bukan digantikan)
  # dan keputusan yang tadinya digantikannya dipulihkan menjadi terkini.
  def self.revoke_for_case!(clinical_case, by:, reason:)
    transaction do
      current.where(clinical_case: clinical_case).find_each do |decision|
        before_state = decision.lifecycle_snapshot
        decision.with_lifecycle_transition do
          decision.update!(decision_status: "revoked", revoked_at: Time.current, revoked_by: by,
            revocation_reason: reason.to_s.strip, superseded_at: Time.current, superseded_by_id: nil)
        end
        decision.record_event!("revoked", by: by, reason: reason, before_state: before_state,
          after_state: decision.lifecycle_snapshot)
        where(superseded_by_id: decision.id).each do |previous|
          old_state = previous.lifecycle_snapshot
          restored_status = previous.epa_promotion&.status == "restricted" ? "restricted" : "active"
          previous.with_lifecycle_transition do
            previous.update!(superseded_by_id: nil, superseded_at: nil, decision_status: restored_status)
          end
          previous.record_event!("corrected", by: by, reason: "Pemulihan setelah pembatalan verifikasi kasus.",
            before_state: old_state, after_state: previous.lifecycle_snapshot)
        end
      end
    end
  end

  def self.revoke_for_epa!(student:, epa:, reason:, by:, promotion: nil)
    raise ArgumentError, "Alasan pencabutan minimal 10 karakter." if reason.to_s.strip.length < MIN_JUSTIFICATION
    raise ArgumentError, "Aktor pencabutan wajib ditentukan." if by.blank?

    transaction do
      active_decisions = current.where(student: student, epa: epa)
      raise ArgumentError, "Tidak ada keputusan entrustment aktif untuk dicabut." unless active_decisions.exists?

      active_decisions.each do |decision|
        before_state = decision.lifecycle_snapshot
        decision.with_lifecycle_transition do
          decision.update!(decision_status: "revoked", revoked_at: Time.current, revoked_by: by,
            revocation_reason: reason.to_s.strip, revocation_epa_promotion: promotion,
            superseded_at: Time.current, superseded_by_id: nil)
        end
        decision.record_event!("revoked", by: by, reason: reason.to_s.strip,
          before_state: before_state, after_state: decision.lifecycle_snapshot)
      end
    end
  end

  def revoked? = decision_status == "revoked"

  def expire!(at: Time.current)
    return false unless decision_status.in?(%w[active restricted]) && valid_until.present? && valid_until <= at

    before_state = lifecycle_snapshot
    with_lifecycle_transition { update!(decision_status: "expired") }
    record_event!("expired", by: nil, reason: "Masa berlaku keputusan berakhir.",
      before_state: before_state, after_state: lifecycle_snapshot)
    true
  end

  def lifecycle_snapshot
    attributes.slice("decision_kind", "decision_status", "level", "epa_id", "competency_item_id",
      "activity_description", "scope_limitations", "context", "valid_from", "valid_until",
      "revoked_at", "revoked_by_id", "revocation_reason", "superseded_at", "superseded_by_id")
  end

  def record_event!(event_type, by:, reason: nil, before_state: {}, after_state: lifecycle_snapshot)
    events.create!(event_type: event_type, actor: by, reason: reason.to_s.presence,
      before_state: before_state, after_state: after_state, occurred_at: Time.current)
  end

  def with_lifecycle_transition
    @lifecycle_transition_authorized = true
    yield
  ensure
    @lifecycle_transition_authorized = false
  end

  # Peta EPA seorang mahasiswa: [ranah, keputusan terkini atau nil] untuk
  # semua ranah kerangka kompetensi.
  def self.map_for(student, framework)
    latest = current.where(student: student, epa_id: framework.epas.select(:id), decision_kind: "summative")
      .includes(:decided_by).index_by(&:epa_id)
    framework.epas.order(:title).map { |epa| [epa, latest[epa.id]] }
  end

  def self.legacy_epa_for(competency_item)
    return if competency_item.blank? || !competency_item.domain?

    Epa.find_by(competency_framework_id: competency_item.competency_framework_id,
                code: "LEGACY-#{competency_item.id}")
  end

  private

  def assign_lifecycle_defaults
    self.decision_kind ||= epa_promotion.present? ? "summative" : "legacy"
    self.decision_status ||= epa_promotion&.status == "restricted" ? "restricted" : "active"
    self.valid_from ||= created_at || Time.current
  end

  def decision_dossier_kind_matches
    if decision_kind == "summative" && epa_promotion.blank?
      errors.add(:epa_promotion, "keputusan sumatif harus terhubung ke dossier panel")
    elsif decision_kind == "ad_hoc" && epa_promotion.present?
      errors.add(:epa_promotion, "keputusan ad hoc tidak boleh menjadi keputusan CCC")
    end
  end

  def revocation_is_audited
    return unless decision_status == "revoked"
    return if decision_kind == "legacy" && persisted? && revoked_by_id.blank?
    return if revoked_at.present? && revoked_by.present? && revocation_reason.to_s.strip.length >= MIN_JUSTIFICATION

    errors.add(:decision_status, "pencabutan wajib menyimpan aktor, waktu, dan alasan")
  end

  def finalized_decision_is_immutable
    return if @lifecycle_transition_authorized

    errors.add(:base, "Keputusan historis hanya dapat berubah melalui lifecycle yang diaudit")
  end

  def assign_legacy_epa
    self.epa = self.class.legacy_epa_for(competency_item)
  end

  def epa_matches_competency
    if epa.blank?
      errors.add(:activity_description, "aktivitas kontekstual wajib ditentukan") if decision_kind == "ad_hoc" && activity_description.blank?
      errors.add(:epa, "EPA atau aktivitas kontekstual wajib ditentukan") if new_record? && decision_kind != "ad_hoc"
      return
    end
    return if epa.blank? || competency_item.blank?
    return if epa.competency_framework_id == competency_item.competency_framework_id

    errors.add(:epa, "harus menggunakan framework kompetensi yang sama")
  end

  def supervision_level_matches_decision
    if supervision_level.blank?
      errors.add(:supervision_level, "skala supervisi berversi wajib dipilih") if decision_kind == "ad_hoc"
      errors.add(:level, "tingkat legacy harus 1–5") unless LEVELS.key?(level)
      return
    end

    return if supervision_level.supervision_scale_version.use_case == "prospective_entrustment" &&
              supervision_level.ordinal == level

    errors.add(:supervision_level, "harus memakai level skala prospektif yang sama dengan keputusan")
  end

  def promotion_matches_decision
    return if epa_promotion.blank?
    # Later lifecycle changes (restriction, revocation, supersession) retain
    # the original panel decision even when a different chair finalizes them.
    return if persisted? && !will_save_change_to_epa_promotion_id?
    return if epa_promotion.status.in?(%w[approved restricted revoked not_entrusted deferred]) && epa_promotion.student_id == student_id &&
              epa_promotion.epa_id == epa_id && epa_promotion.reviewed_by_id == decided_by_id

    errors.add(:epa_promotion, "harus merupakan tinjauan yang disetujui untuk mahasiswa dan EPA yang sama")
  end
end
