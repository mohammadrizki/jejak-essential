# frozen_string_literal: true

# Program studi dikelola sebagai master data. Seed menyediakan contoh Sarjana
# Kedokteran dan Profesi Dokter; program Spesialis/Subspesialis ditambahkan
# lewat konfigurasi dengan kode dan jenjang masing-masing.
class StudyProgram < ApplicationRecord
  LEVELS = {
    "sarjana" => "Sarjana",
    "profesi" => "Profesi",
    "spesialis" => "Spesialis",
    "subspesialis" => "Subspesialis"
  }.freeze
  SHOWCASE_CODES = %w[demo-canmeds-sarjana].freeze

  scope :showcases, -> { where(code: SHOWCASE_CODES) }

  has_many :users, dependent: :nullify
  has_many :framework_versions, class_name: "CompetencyFramework", dependent: :restrict_with_error
  has_one :assessment_blueprint, dependent: :restrict_with_error
  has_many :assessment_form_templates, dependent: :restrict_with_error

  # Kerangka Peta EPA prodi ini — lihat CompetencyFramework.for_student.
  belongs_to :competency_framework, optional: true
  belongs_to :srq_enabled_by, class_name: "User", optional: true

  validates :name, presence: true, uniqueness: true
  validates :code, presence: true, uniqueness: true, format: { with: /\A[a-z0-9\-]+\z/, message: "hanya huruf kecil, angka, dan tanda hubung" }
  validates :level, inclusion: { in: LEVELS.keys }
  validates :epa_panel_quorum, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 10 }
  validate :competency_framework_belongs_to_program
  scope :ordered, -> { order(:level, :name) }

  def level_label
    LEVELS.fetch(level, level)
  end

  # Compatibility accessor for program configuration and portfolio flows.
  # Draft-only programs can configure an initial map; an archived pointer is
  # an explicit withdrawal and must not fall through to an unreviewed draft.
  def peta_kompetensi
    # An archived pointer is an explicit withdrawal marker. Do not fall back
    # to a correction draft and expose it as the program's active framework.
    return nil if competency_framework&.study_program_id == id && competency_framework.status == "archived"
    return competency_framework if competency_framework&.study_program_id == id

    framework_versions.where.not(status: "archived")
      .order(Arel.sql("CASE status WHEN 'published' THEN 0 ELSE 1 END"), created_at: :desc, id: :desc).first
  end

  def sarjana?
    level == "sarjana"
  end

  def profesi?
    level == "profesi"
  end

  def spesialis?
    level == "spesialis"
  end

  def subspesialis?
    level == "subspesialis"
  end

  def showcase?
    code.in?(SHOWCASE_CODES)
  end

  # SRQ-20 menampilkan tanda "Perlu Perhatian Segera" yang hanya bisa dilihat
  # kaprodi, jadi kaprodi prodi itu yang mengaktifkannya setelah SOP siap.
  def srq_enabled? = srq_enabled_at.present?

  def enable_srq!(by:)
    update!(srq_enabled_at: Time.current, srq_enabled_by: by)
  end

  def disable_srq!
    update!(srq_enabled_at: nil, srq_enabled_by: nil)
  end

  private

  def competency_framework_belongs_to_program
    return if competency_framework.blank? || competency_framework.study_program_id == id

    errors.add(:competency_framework, "harus dimiliki oleh program studi ini")
  end

end
