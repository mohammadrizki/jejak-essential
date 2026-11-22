# frozen_string_literal: true

class MiniCexEvaluation < ApplicationRecord
  include DimensionScorable
  include ClinicalContextOptions

  # 6 dimensi numerik (1-9) rubrik Mini-CEX. Penilaian
  # keseluruhan TIDAK jadi dimensi numerik ke-7 lagi — dipindah ke
  # `global_rating`, field kualitatif 4-pilihan terpisah (lihat
  # GLOBAL_RATING_OPTIONS), karena itu memang bagaimana Mini-CEX standar
  # menilainya (bukan skala 1-9).
  DIMENSIONS = {
    "anamnesis" => "Keterampilan Anamnesis",
    "pemeriksaan_fisik" => "Keterampilan Pemeriksaan Fisik",
    "clinical_judgment" => "Clinical Judgment",
    "komunikasi" => "Keterampilan Komunikasi",
    "profesionalisme" => "Profesionalisme",
    "organisasi" => "Organisasi & Efisiensi"
  }.freeze
  REQUIRED_DIMENSIONS = %w[komunikasi profesionalisme].freeze

  GLOBAL_RATING_OPTIONS = {
    "needs_development" => "Perlu Banyak Perbaikan",
    "borderline" => "Batas Bawah",
    "performed" => "Sesuai Harapan",
    "exceptional" => "Melebihi Harapan"
  }.freeze

  belongs_to :student, class_name: "User"
  belongs_to :evaluator, class_name: "User"
  belongs_to :clinical_rotation
  belongs_to :wpba_instrument_version, optional: true
  belongs_to :corrects, class_name: "MiniCexEvaluation", optional: true, inverse_of: :corrections
  has_many :corrections, class_name: "MiniCexEvaluation", foreign_key: :corrects_id,
    inverse_of: :corrects, dependent: :restrict_with_error
  has_many :evidence_records, dependent: :restrict_with_error

  validates :case_description, presence: true
  validates :global_rating, inclusion: { in: GLOBAL_RATING_OPTIONS.keys }, unless: :requested?
  validates :correction_reason, presence: true, length: { minimum: 10, maximum: 1000 }, if: :correction?
  validate :correction_matches_source
  before_validation :assign_current_instrument_version, on: :create
  before_update :submitted_result_is_immutable
  before_destroy :submitted_record_is_preserved

  scope :recent, -> { order(evaluated_at: :desc) }
  scope :submitted_history, -> { where(status: "submitted") }
  scope :submitted, -> {
    where(status: "submitted").where.not(id: where(status: "submitted").where.not(corrects_id: nil).select(:corrects_id))
  }

  def correction? = corrects_id.present?

  def correction_root
    node = self
    node = node.corrects while node.corrects.present?
    node
  end

  def source_activity_key
    "#{self.class.name.underscore}:#{correction_root.id || id}"
  end

  def global_rating_label
    GLOBAL_RATING_OPTIONS.fetch(global_rating, global_rating)
  end

  private

  def assign_current_instrument_version
    return if corrects.present?

    self.wpba_instrument_version ||= WpbaInstrumentCatalog.version_for("mini_cex")
  end

  def submitted_result_is_immutable
    return unless status_in_database == "submitted" && (changes_to_save.keys - %w[updated_at]).any?

    errors.add(:base, "Evaluasi terkirim tidak dapat ditimpa; buat evaluasi koreksi baru agar jejak audit terjaga.")
    throw(:abort)
  end

  def correction_matches_source
    return unless corrects

    errors.add(:corrects, "harus merujuk evaluasi terkirim") unless corrects.submitted?
    errors.add(:student, "harus sama dengan evaluasi yang dikoreksi") unless student_id == corrects.student_id
    errors.add(:clinical_rotation, "harus sama dengan evaluasi yang dikoreksi") unless clinical_rotation_id == corrects.clinical_rotation_id
    errors.add(:clinical_case, "harus sama dengan evaluasi yang dikoreksi") unless clinical_case_id == corrects.clinical_case_id
    errors.add(:evaluated_at, "harus sama dengan tanggal observasi sumber") unless evaluated_at == corrects.evaluated_at
    errors.add(:wpba_instrument_version, "harus tetap menggunakan versi instrumen sumber") unless
      wpba_instrument_version_id == corrects.wpba_instrument_version_id
    errors.add(:correction_reason, "wajib menjelaskan alasan koreksi") if correction_reason.to_s.strip.length < 10
  end

  def submitted_record_is_preserved
    return unless submitted?

    errors.add(:base, "Evaluasi terkirim adalah riwayat final; buat koreksi untuk memperbaikinya")
    throw(:abort)
  end

  def notify_student
    Notification.notify!(
      recipient: student, sender: evaluator, notifiable: self,
      title: "Mini-CEX baru: #{case_description}",
      message: "Skor rata-rata: #{average_score || "-"}/9"
    )
  end
end
