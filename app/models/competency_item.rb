# frozen_string_literal: true

class CompetencyItem < ApplicationRecord
  belongs_to :competency_framework
  belongs_to :parent, class_name: "CompetencyItem", optional: true, inverse_of: :children
  has_many :children, -> { order(:position) }, class_name: "CompetencyItem", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent
  has_many :competency_milestones, dependent: :destroy
  has_many :competency_attainments, dependent: :restrict_with_error
  has_many :evidence_requirements, dependent: :restrict_with_error
  has_many :competency_indicators, -> { order(:position) }, dependent: :restrict_with_error
  has_many :blueprint_item_competencies, dependent: :restrict_with_error
  has_many :blueprint_items, through: :blueprint_item_competencies
  has_many :epa_competencies, dependent: :restrict_with_error
  has_many :epas, through: :epa_competencies
  has_many :assessment_blueprint_mappings, dependent: :destroy
  has_many :activity_log_competency_tags, dependent: :destroy
  # Pemetaan dimensi ujian / pertanyaan rubrik dilepas, bukan ikut dihapus.
  has_many :assessment_dimensions, dependent: :nullify
  has_many :assessment_form_fields, dependent: :nullify
  # Keputusan entrustment (Peta EPA) adalah nilai mahasiswa: simpul yang —
  # atau yang sub-kompetensinya — sudah dipakai tidak bisa dihapus. Dijalankan
  # paling awal, sebelum anak-anaknya ikut terhapus.
  has_many :entrustment_decisions
  before_destroy :ensure_unused_by_entrustment, prepend: true

  validates :title, :code, presence: true
  validates :level_type, inclusion: { in: %w[domain competency subcompetency] }
  validates :code, uniqueness: { scope: :competency_framework_id }
  validate :code_is_unique_across_framework_entries
  validate :expected_evidence_types_are_supported

  before_create :assign_position
  before_validation :assign_level_type
  before_validation :assign_code
  validate :parent_matches_framework
  validate :parent_hierarchy_is_valid
  validate :framework_is_draft_for_changes
  before_destroy :framework_is_draft_for_deletion, prepend: true

  def domain?
    parent_id.nil?
  end

  def hierarchy_path
    nodes = [ self ]
    ancestor = parent
    while ancestor
      nodes.unshift(ancestor)
      ancestor = ancestor.parent
    end
    nodes.map { |node| "#{node.code} · #{node.title}" }.join(" / ")
  end

  # Id simpul ini beserta seluruh keturunannya.
  def subtree_ids
    ids = [ id ]
    level = [ id ]
    while (level = CompetencyItem.where(parent_id: level).pluck(:id)).any?
      ids.concat(level)
    end
    ids
  end

  private

  def ensure_unused_by_entrustment
    return unless EntrustmentDecision.exists?(competency_item_id: subtree_ids)

    errors.add(:base, "sudah dipakai pada keputusan entrustment (Peta EPA) mahasiswa")
    throw :abort
  end

  def assign_position
    siblings = parent_id ? CompetencyItem.where(parent_id: parent_id) : competency_framework.domains
    self.position = (siblings.maximum(:position) || 0) + 1
  end

  def assign_code
    return if code.present? || competency_framework.blank?

    base = "#{parent_id.nil? ? 'DOMAIN' : 'COMP'}-#{title.to_s.parameterize.upcase.presence || 'ITEM'}"
    existing = competency_framework.competency_items.where.not(id: id).pluck(:code).compact +
      competency_framework.competency_indicators.pluck(:code).compact
    candidate = base
    suffix = 2
    while existing.include?(candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end
    self.code = candidate
  end

  def code_is_unique_across_framework_entries
    return if code.blank? || competency_framework.blank?
    return unless competency_framework.competency_indicators.where(code: code).exists?

    errors.add(:code, "sudah digunakan oleh indikator pada framework ini")
  end

  def assign_level_type
    self.level_type = if parent_id.nil?
      "domain"
    elsif parent&.level_type == "domain"
      "competency"
    else
      "subcompetency"
    end
  end

  def parent_matches_framework
    return if parent.blank? || parent.competency_framework_id == competency_framework_id

    errors.add(:parent, "harus berada dalam framework yang sama")
  end

  def parent_hierarchy_is_valid
    return if parent.blank?
    errors.add(:parent, "tidak boleh menunjuk ke simpul yang sama") if parent_id == id
    errors.add(:parent, "hanya ranah atau kompetensi yang dapat menjadi parent") if parent.level_type == "subcompetency"
  end

  def framework_is_draft_for_changes
    return if competency_framework&.status == "draft"
    return if persisted? && !changed?

    errors.add(:base, "Kompetensi framework terbit tidak dapat diubah; buat versi draf terlebih dahulu")
  end

  def framework_is_draft_for_deletion
    return if competency_framework&.status == "draft"

    errors.add(:base, "Simpul pada framework terbit tidak dapat dihapus; buat versi draf terlebih dahulu")
    throw :abort
  end

  def expected_evidence_types_are_supported
    allowed = %w[observasi artefak asesmen refleksi]
    return if expected_evidence_types.is_a?(Array) && (expected_evidence_types - allowed).empty?

    errors.add(:expected_evidence_types, "berisi jenis bukti yang tidak dikenal")
  end
end
