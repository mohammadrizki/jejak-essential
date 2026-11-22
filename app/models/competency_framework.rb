# frozen_string_literal: true

class CompetencyFramework < ApplicationRecord
  belongs_to :study_program
  has_many :epa_programs, class_name: "StudyProgram", foreign_key: :competency_framework_id, dependent: :nullify
  has_many :competency_items, -> { order(:position) }, dependent: :destroy, inverse_of: :competency_framework
  has_many :competency_indicators, through: :competency_items
  has_many :epas, dependent: :restrict_with_error
  has_many :epa_milestones, through: :epas
  has_many :blueprint_versions, dependent: :restrict_with_error
  # Diperiksa sebelum simpul-simpulnya dihapus (lihat CompetencyItem).
  before_destroy :ensure_unused_by_entrustment, prepend: true
  before_destroy :prevent_destroy_with_historical_references, prepend: true

  validates :name, :version, presence: true
  validates :version, uniqueness: { scope: :study_program_id }
  validates :status, inclusion: { in: %w[draft published archived] }
  validates :education_stage, presence: true, inclusion: { in: StudyProgram::LEVELS.keys }
  validate :program_change_preserves_curriculum_ownership
  before_validation :assign_version_and_education_stage, on: :create
  before_save :archive_previous_published_versions, if: :should_archive_previous_versions?
  after_save :update_program_framework_pointer, if: :published?
  after_save :publish_draft_epas, if: -> { published? && saved_change_to_status? }
  before_destroy :prevent_published_framework_deletion
  validate :published_framework_is_immutable
  validate :published_framework_has_domain, if: :published?
  validate :education_stage_matches_program

  # Peta kompetensi utama milik program studi mahasiswa.
  def self.for_student(student)
    student&.study_program&.peta_kompetensi
  end

  def domains
    competency_items.where(parent_id: nil)
  end

  def published? = status == "published"

  def publish!
    if domains.empty?
      errors.add(:competency_items, "tambahkan setidaknya satu domain sebelum menerbitkan framework")
      raise ActiveRecord::RecordInvalid.new(self)
    end

    @allow_lifecycle_status_transition = true
    update!(status: "published")
  ensure
    @allow_lifecycle_status_transition = false
  end

  # Only called by CompetencyFrameworkLifecycle after it verifies that no
  # historical academic record depends on this published definition. The
  # definition is archived; corrections happen on a separately copied draft.
  def archive_unpublished!
    @allow_lifecycle_status_transition = true
    update!(status: "archived")
  ensure
    @allow_lifecycle_status_transition = false
  end

  # A safe, dependency-free archived draft is temporarily made editable only
  # inside the same transaction that removes it and its configuration.
  def prepare_for_safe_deletion!
    return if status == "draft"

    @allow_lifecycle_status_transition = true
    update!(status: "draft")
  ensure
    @allow_lifecycle_status_transition = false
  end

  private

  def assign_version_and_education_stage
    self.status = "draft"
    latest_version = study_program&.framework_versions&.pluck(:version)&.filter_map { |value| Integer(value, exception: false) }&.max || 0
    self.version = (latest_version + 1).to_s if version.blank? ||
                   study_program&.framework_versions&.exists?(version: version)
    self.education_stage ||= study_program&.level
  end

  def published_framework_is_immutable
    return unless persisted?
    if will_save_change_to_status? && !@allow_lifecycle_status_transition
      errors.add(:status, "gunakan tindakan lifecycle Unpublish atau Terbitkan")
      return
    end
    return unless %w[published archived].include?(status_in_database)
    return if (changes_to_save.keys - ["status"]).empty?

    errors.add(:base, "Framework terbit/arsip bersifat historis; buat versi baru untuk mengubah isinya")
    errors.add(:status, "versi arsip tidak dapat diterbitkan ulang") if status_in_database == "archived" && status == "published"
  end

  def prevent_published_framework_deletion
    return if status == "draft"
    return if status == "archived" && CompetencyFrameworkLifecycle.new(self).deletable?

    errors.add(:base, "Framework terbit atau arsip yang masih menjadi referensi historis tidak dapat dihapus")
    throw :abort
  end

  def prevent_destroy_with_historical_references
    blockers = CompetencyFrameworkLifecycle.new(self).deletion_blockers
    return if blockers.empty?

    errors.add(:base, "masih digunakan oleh #{blockers.to_sentence}")
    throw :abort
  end

  def should_archive_previous_versions?
    published? && (new_record? || will_save_change_to_status?)
  end

  def archive_previous_published_versions
    study_program.framework_versions.where(status: "published").where.not(id: id)
                 .update_all(status: "archived", updated_at: Time.current)
  end

  def update_program_framework_pointer
    study_program.update_column(:competency_framework_id, id)
  end

  def publish_draft_epas
    epas.where(status: "draft").update_all(status: "published", updated_at: Time.current)
  end

  def ensure_unused_by_entrustment
    return unless EntrustmentDecision.exists?(competency_item_id: competency_items.select(:id))

    errors.add(:base, "sudah dipakai pada keputusan entrustment (Peta EPA) mahasiswa")
    throw :abort
  end

  def program_change_preserves_curriculum_ownership
    return unless persisted? && will_save_change_to_study_program_id?

    errors.add(:study_program, "tidak dapat diubah setelah framework digunakan; buat versi baru untuk program studi yang benar")
  end

  def published_framework_has_domain
    errors.add(:competency_items, "tambahkan setidaknya satu domain sebelum menerbitkan framework") unless domains.exists?
  end

  def education_stage_matches_program
    expected_stage = study_program&.level
    return if education_stage.blank? || education_stage == expected_stage

    errors.add(:education_stage, "harus sesuai dengan jenjang program studi")
  end
end
