# frozen_string_literal: true

class BlueprintVersion < ApplicationRecord
  belongs_to :assessment_blueprint
  belongs_to :competency_framework
  has_many :blueprint_items, -> { order(:position) }, dependent: :restrict_with_error

  validates :version, numericality: { only_integer: true, greater_than: 0 },
                      uniqueness: { scope: :assessment_blueprint_id }
  validates :status, inclusion: { in: %w[draft published archived] }
  validate :framework_matches_program
  validate :framework_is_published_when_publishing, if: -> { status == "published" }
  validate :published_version_is_immutable
  validate :published_version_has_items, if: -> { status == "published" }

  def publish!
    if blueprint_items.empty?
      errors.add(:blueprint_items, "tambahkan setidaknya satu komponen sebelum menerbitkan blueprint")
      raise ActiveRecord::RecordInvalid.new(self)
    end

    transaction do
      assessment_blueprint.blueprint_versions.where(status: "published").where.not(id: id)
                           .update_all(status: "archived", updated_at: Time.current)
      update!(status: "published")
    end
  end

  private

  def framework_matches_program
    return if competency_framework.blank? || assessment_blueprint.blank?
    return if competency_framework.study_program_id == assessment_blueprint.study_program_id

    errors.add(:competency_framework, "harus berasal dari program studi blueprint")
  end

  def framework_is_published_when_publishing
    return if competency_framework&.status == "published"

    errors.add(:competency_framework, "harus sudah diterbitkan sebelum blueprint ini diterbitkan")
  end

  def published_version_has_items
    errors.add(:blueprint_items, "tambahkan setidaknya satu komponen sebelum menerbitkan blueprint") unless blueprint_items.exists?
  end

  def published_version_is_immutable
    return unless persisted? && %w[published archived].include?(status_in_database)
    return if (changes_to_save.keys - ["status"]).empty?

    errors.add(:base, "Versi blueprint terbit/arsip bersifat historis")
    errors.add(:status, "versi arsip tidak dapat diterbitkan ulang") if status_in_database == "archived" && status == "published"
  end
end
