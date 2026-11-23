# frozen_string_literal: true

# Rencana cakupan asesmen tunggal milik satu program studi.
class AssessmentBlueprint < ApplicationRecord
  attr_accessor :initial_competency_framework_id, :skip_initial_outline
  belongs_to :study_program
  has_many :assessment_blueprint_mappings, dependent: :destroy
  has_many :competency_items, through: :assessment_blueprint_mappings
  has_many :learning_units, dependent: :nullify
  has_many :blueprint_versions, -> { order(version: :desc) }, dependent: :restrict_with_error

  validates :name, presence: true
  validates :study_program_id, uniqueness: true
  validate :program_change_preserves_version_ownership
  after_create :create_initial_version
  validate :initial_framework_belongs_to_program, on: :create

  def current_version
    blueprint_versions.find_by(status: "published") || blueprint_versions.first
  end

  def draft_version
    blueprint_versions.find_by(status: "draft")
  end

  # Mapping ditambah satu per satu, jadi total di tengah penyusunan wajar
  # belum 100% — itu ditandai di halaman detail (weights_complete?), bukan
  # divalidasi di sini: dulu validasi "harus 100%" di blueprint justru
  # mengunci sunting nama/deskripsi selama mapping belum lengkap, padahal
  # tidak pernah mencegah mapping baru mendorong total melewati 100%. Batas
  # atas itu kini dijaga AssessmentBlueprintMapping.
  def total_weight
    competency_weight_mappings.sum { |mapping| mapping.weight.to_f }
  end

  def weights_complete?
    (total_weight - 100).abs < 0.01
  end

  def remaining_weight
    (100 - total_weight).round(1)
  end

  def competency_weight_mappings
    mappings = assessment_blueprint_mappings.includes(:competency_item).to_a
    framework_id = (draft_version || current_version)&.competency_framework_id
    return mappings if framework_id.blank?

    mappings.select { |mapping| mapping.competency_item.competency_framework_id == framework_id }
  end

  # {CompetencyItem => bobot} — dipakai halaman show untuk radar chart,
  # sudah dalam bentuk siap-pakai (bukan JSONB label bebas lagi).
  def weight_by_competency_item
    competency_weight_mappings.index_by(&:competency_item).transform_values { |mapping| mapping.weight.to_f }
  end

  # Keep the Blueprint spiderweb readable while preserving the same scale for
  # each student's overlay. The axis maximum follows the largest benchmark
  # weight, rounded up to the next ten.
  def competency_weight_chart_max
    maximum_weight = competency_weight_mappings.map { |mapping| mapping.weight.to_f }.max.to_f
    return 100 if maximum_weight <= 0

    (maximum_weight / 10.0).ceil * 10
  end

  private

  def create_initial_version
    framework = initial_competency_framework || study_program.peta_kompetensi
    return if framework.blank?

    version = blueprint_versions.create!(competency_framework: framework, version: 1, status: "draft")
    BlueprintOutlineBuilder.new(version: version).call unless skip_initial_outline
  end

  def initial_competency_framework
    return study_program&.framework_versions&.find_by(id: initial_competency_framework_id) if initial_competency_framework_id.present?

    framework = study_program&.peta_kompetensi
    framework if framework&.published?
  end

  def program_change_preserves_version_ownership
    return unless persisted? && will_save_change_to_study_program_id? && blueprint_versions.exists?

    errors.add(:study_program, "tidak dapat diubah setelah versi blueprint dibuat")
  end

  def initial_framework_belongs_to_program
    framework = initial_competency_framework
    return if framework.present? && framework.study_program_id == study_program_id && framework.published?

    errors.add(:initial_competency_framework_id, "harus berupa Peta Kompetensi terbit milik program studi yang dipilih")
  end

end
