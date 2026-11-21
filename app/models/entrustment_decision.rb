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

  belongs_to :student, class_name: "User"
  belongs_to :competency_item, optional: true
  belongs_to :epa, optional: true
  belongs_to :decided_by, class_name: "User"
  belongs_to :clinical_case, optional: true
  belongs_to :superseded_by, class_name: "EntrustmentDecision", optional: true
  belongs_to :supervision_level, optional: true
  belongs_to :epa_promotion, optional: true

  validates :justification, presence: true, length: { minimum: MIN_JUSTIFICATION, message: "minimal #{MIN_JUSTIFICATION} karakter" }
  before_validation :assign_legacy_epa, if: -> { epa_id.nil? }
  validate :epa_matches_competency
  validate :supervision_level_matches_decision
  validate :promotion_matches_decision

  scope :current, -> { where(superseded_at: nil) }
  scope :history, -> { order(created_at: :desc) }

  def level_label = supervision_level&.label || LEVELS[level]

  def epa_title = epa&.title || competency_item&.title

  # Membuat keputusan baru dan menandai keputusan lama (mahasiswa × ranah
  # yang sama) sebagai tergantikan — atomik.
  def self.decide!(student:, competency_item: nil, epa: nil, level:, justification:, decided_by:, clinical_case: nil,
                   supervision_level: nil, epa_promotion: nil)
    transaction do
      epa ||= legacy_epa_for(competency_item)
      decision = create!(student: student, competency_item: competency_item, epa: epa, level: level,
                         justification: justification, decided_by: decided_by, clinical_case: clinical_case,
                         supervision_level: supervision_level, epa_promotion: epa_promotion)
      scope = current.where(student: student)
      scope = epa.present? ? scope.where(epa: epa) : scope.where(competency_item: competency_item)
      scope.where.not(id: decision.id)
             .update_all(superseded_by_id: decision.id, superseded_at: Time.current)
      decision
    end
  end

  # Verifikasi kasus dibatalkan: keputusan TERKINI yang lahir dari kasus itu
  # dicabut (superseded_at tanpa superseded_by = dicabut, bukan digantikan)
  # dan keputusan yang tadinya digantikannya dipulihkan menjadi terkini.
  def self.revoke_for_case!(clinical_case)
    transaction do
      current.where(clinical_case: clinical_case).find_each do |decision|
        where(superseded_by_id: decision.id).update_all(superseded_by_id: nil, superseded_at: nil)
        decision.update_columns(superseded_at: Time.current)
      end
    end
  end

  def revoked?
    superseded_at.present? && superseded_by_id.nil?
  end

  # Peta EPA seorang mahasiswa: [ranah, keputusan terkini atau nil] untuk
  # semua ranah kerangka kompetensi.
  def self.map_for(student, framework)
    return [] if framework.education_stage == "undergraduate"

    latest = current.where(student: student, epa_id: framework.epas.select(:id)).includes(:decided_by).index_by(&:epa_id)
    framework.epas.order(:title).map { |epa| [epa, latest[epa.id]] }
  end

  def self.legacy_epa_for(competency_item)
    return if competency_item.blank? || !competency_item.domain?

    Epa.find_by(competency_framework_id: competency_item.competency_framework_id,
                code: "LEGACY-#{competency_item.id}")
  end

  private

  def assign_legacy_epa
    self.epa = self.class.legacy_epa_for(competency_item)
  end

  def epa_matches_competency
    if epa.blank?
      errors.add(:epa, "EPA wajib ditentukan untuk keputusan entrustment") if new_record?
      return
    end
    if epa.competency_framework.education_stage == "undergraduate"
      errors.add(:epa, "Entrustment EPA hanya berlaku untuk tahap Profesi, Spesialis, dan Subspesialis")
    end
    return if epa.blank? || competency_item.blank?
    return if epa.competency_framework_id == competency_item.competency_framework_id

    errors.add(:epa, "harus menggunakan framework kompetensi yang sama")
  end

  def supervision_level_matches_decision
    if supervision_level.blank?
      errors.add(:level, "tingkat legacy harus 1–5") unless LEVELS.key?(level)
      return
    end

    return if supervision_level.supervision_scale_version.use_case == "prospective_entrustment" &&
              supervision_level.ordinal == level

    errors.add(:supervision_level, "harus memakai level skala prospektif yang sama dengan keputusan")
  end

  def promotion_matches_decision
    return if epa_promotion.blank?
    return if epa_promotion.status == "approved" && epa_promotion.student_id == student_id &&
              epa_promotion.epa_id == epa_id && epa_promotion.reviewed_by_id == decided_by_id

    errors.add(:epa_promotion, "harus merupakan tinjauan yang disetujui untuk mahasiswa dan EPA yang sama")
  end
end
