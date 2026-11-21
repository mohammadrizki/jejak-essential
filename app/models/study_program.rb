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

  has_many :users, dependent: :nullify
  has_many :framework_versions, class_name: "CompetencyFramework", dependent: :restrict_with_error
  has_one :assessment_blueprint, dependent: :restrict_with_error

  # Kerangka Peta EPA prodi ini — lihat CompetencyFramework.for_student.
  belongs_to :competency_framework, optional: true
  belongs_to :srq_enabled_by, class_name: "User", optional: true

  validates :name, presence: true, uniqueness: true
  validates :code, presence: true, uniqueness: true, format: { with: /\A[a-z0-9\-]+\z/, message: "hanya huruf kecil, angka, dan tanda hubung" }
  validates :level, inclusion: { in: LEVELS.keys }
  scope :ordered, -> { order(:level, :name) }

  def level_label
    LEVELS.fetch(level, level)
  end

  # Compatibility accessor used throughout the portfolio. Published versions
  # are preferred; draft-only programs can still configure their first map.
  def peta_kompetensi
    framework_versions.order(Arel.sql("CASE status WHEN 'published' THEN 0 ELSE 1 END"), created_at: :desc, id: :desc).first
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

  # SRQ-20 menampilkan tanda "Perlu Perhatian Segera" yang hanya bisa dilihat
  # kaprodi, jadi kaprodi prodi itu yang mengaktifkannya setelah SOP siap.
  def srq_enabled? = srq_enabled_at.present?

  def enable_srq!(by:)
    update!(srq_enabled_at: Time.current, srq_enabled_by: by)
  end

  def disable_srq!
    update!(srq_enabled_at: nil, srq_enabled_by: nil)
  end

end
