# frozen_string_literal: true

class WpbaObservation < ApplicationRecord
  belongs_to :student, class_name: "User", inverse_of: :wpba_observations_as_student
  belongs_to :observer, class_name: "User", inverse_of: :wpba_observations_as_observer
  belongs_to :clinical_rotation
  belongs_to :clinical_case, optional: true
  belongs_to :wpba_instrument_version
  belongs_to :corrects, class_name: "WpbaObservation", optional: true, inverse_of: :corrections
  has_many :corrections, class_name: "WpbaObservation", foreign_key: :corrects_id,
    inverse_of: :corrects, dependent: :restrict_with_error
  has_many :evidence_records, dependent: :restrict_with_error

  validates :observed_at, presence: true
  validates :status, inclusion: { in: %w[draft submitted] }
  validates :submitted_at, presence: true, if: :submitted?
  validates :correction_reason, presence: true, length: { minimum: 10, maximum: 1000 }, if: :correction?
  validate :instrument_is_custom_and_published
  validate :assignment_covers_observation
  validate :clinical_case_belongs_to_student
  validate :context_is_structured
  validate :responses_are_structured
  validate :responses_follow_instrument
  validate :correction_preserves_observation

  before_validation :normalize_json_fields
  before_update :submitted_observation_is_immutable
  before_destroy :submitted_observation_is_preserved
  after_update :propagate_correction_evidence,
    if: -> { corrects_id.present? && saved_change_to_status? && submitted? }
  after_commit :notify_student_when_submitted, on: %i[create update]

  scope :submitted_history, -> { where(status: "submitted") }
  scope :submitted, -> {
    where(status: "submitted").where.not(id: where(status: "submitted").where.not(corrects_id: nil).select(:corrects_id))
  }
  scope :recent, -> { order(observed_at: :desc, id: :desc) }

  def submitted? = status == "submitted"
  def correction? = corrects_id.present?

  def correction_root
    node = self
    node = node.corrects while node.corrects.present?
    node
  end

  def source_activity_key
    "wpba_observation:#{correction_root.id || id}"
  end

  def multisource_feedback?
    wpba_instrument_version.wpba_instrument.instrument_type == "msf"
  end

  def multisource_group
    return self.class.none unless multisource_feedback?

    self.class.submitted.where(student_id: student_id, clinical_rotation_id: clinical_rotation_id,
      wpba_instrument_version_id: wpba_instrument_version_id).includes(:observer).order(:observed_at, :id)
  end

  def multisource_required_raters
    [wpba_instrument_version.definition.to_h.fetch("minimum_raters", 3).to_i, 3].max
  end

  def multisource_ready?
    multisource_group.map(&:observer_id).uniq.size >= multisource_required_raters
  end

  def multisource_average_for(key)
    values = multisource_group.filter_map { |observation| Integer(observation.response_for(key), exception: false) }
    return if values.empty?

    (values.sum.to_f / values.size).round(1)
  end

  def response_for(key)
    responses.is_a?(Hash) ? responses[key.to_s] : nil
  end

  def submit!
    return if submitted?

    update!(status: "submitted", submitted_at: Time.current)
  end

  private

  def normalize_json_fields
    self.clinical_context = clinical_context.deep_stringify_keys if clinical_context.is_a?(Hash)
    self.responses = responses.deep_stringify_keys if responses.is_a?(Hash)
  end

  def instrument_is_custom_and_published
    version = wpba_instrument_version
    errors.add(:wpba_instrument_version, "wajib menggunakan versi terbit") if version && version.published_at.blank?
    errors.add(:wpba_instrument_version, "bukan instrumen WPBA yang dapat digunakan") if
      version && version.wpba_instrument&.instrument_type.in?(WpbaInstrument::WPBA_TYPES + ["other"]) != true
  end

  def assignment_covers_observation
    return if student.blank? || observer.blank? || clinical_rotation.blank? || observed_at.blank?
    return if AssessmentAssignment.assigned?(assessor: observer, student: student,
      rotation: clinical_rotation, assessed_at: observed_at)

    errors.add(:observer, "tidak memiliki penugasan WPBA pada rotasi dan tanggal observasi ini")
  end

  def clinical_case_belongs_to_student
    return if clinical_case.blank? || clinical_case.user_id == student_id

    errors.add(:clinical_case, "harus menjadi konteks kasus mahasiswa yang dinilai")
  end

  def context_is_structured
    errors.add(:clinical_context, "harus berupa object JSON") unless clinical_context.is_a?(Hash)
    errors.add(:activity_summary, "wajib diisi sebelum observasi dikirim") if submitted? && activity_summary.to_s.strip.blank?
    errors.add(:activity_summary, "maksimal 2000 karakter") if activity_summary.to_s.length > 2000
    errors.add(:overall_feedback, "maksimal 4000 karakter") if overall_feedback.to_s.length > 4000
    errors.add(:action_plan, "maksimal 2000 karakter") if action_plan.to_s.length > 2000
  end

  def responses_are_structured
    errors.add(:responses, "harus berupa object JSON") unless responses.is_a?(Hash)
  end

  def responses_follow_instrument
    return unless wpba_instrument_version
    return unless responses.is_a?(Hash)

    components = wpba_instrument_version.components.map(&:to_h).map(&:deep_stringify_keys)
    allowed = components.filter_map { |component| component["key"] }
    unknown = responses.keys - allowed
    errors.add(:responses, "memuat komponen yang tidak didefinisikan instrumen") if unknown.any?

    components.each do |component|
      key = component["key"].to_s
      value = responses[key]
      if submitted? && component["required"] && value.blank? && !(component["type"] == "boolean" && value == false)
        errors.add(:responses, "#{component['label']} wajib diisi")
        next
      end
      next if value.blank?

      case component["type"]
      when "rating"
        score = Integer(value, exception: false)
        min = Integer(component["minimum"], exception: false)
        max = Integer(component["maximum"], exception: false)
        errors.add(:responses, "#{component['label']} harus antara #{min} dan #{max}") unless score && min && max && score.between?(min, max)
        responses[key] = score if score
      when "text"
        errors.add(:responses, "#{component['label']} maksimal 4000 karakter") if value.to_s.length > 4000
      when "select"
        errors.add(:responses, "pilihan #{component['label']} tidak tersedia pada instrumen") unless
          Array(component["options"]).include?(value.to_s)
      when "boolean"
        if value.in?([ true, false, "true", "false", 1, 0, "1", "0" ])
          responses[key] = ActiveModel::Type::Boolean.new.cast(value)
        else
          errors.add(:responses, "#{component['label']} harus ya/tidak")
        end
      end
    end
  end

  def correction_preserves_observation
    return unless corrects

    errors.add(:corrects, "harus merujuk observasi terkirim") unless corrects.submitted?
    errors.add(:student, "harus sama dengan observasi sumber") unless student_id == corrects.student_id
    errors.add(:clinical_rotation, "harus sama dengan observasi sumber") unless clinical_rotation_id == corrects.clinical_rotation_id
    errors.add(:clinical_case, "harus sama dengan observasi sumber") unless clinical_case_id == corrects.clinical_case_id
    errors.add(:observed_at, "harus sama dengan tanggal observasi sumber") unless observed_at == corrects.observed_at
    errors.add(:wpba_instrument_version, "harus sama dengan instrumen dan versi sumber") unless
      wpba_instrument_version_id == corrects.wpba_instrument_version_id
    errors.add(:correction_reason, "wajib menjelaskan alasan koreksi") if correction_reason.to_s.strip.length < 10
  end

  def submitted_observation_is_immutable
    return unless status_in_database == "submitted" && (changes_to_save.keys - %w[updated_at]).any?

    errors.add(:base, "Observasi terkirim tidak dapat ditimpa; buat koreksi untuk mempertahankan riwayat.")
    throw(:abort)
  end

  def submitted_observation_is_preserved
    return unless submitted?

    errors.add(:base, "Observasi terkirim adalah riwayat final; buat koreksi untuk memperbaikinya")
    throw(:abort)
  end

  def propagate_correction_evidence
    source = EvidenceSource.for_local_record!(self)
    corrects.evidence_records.find_each do |previous_record|
      record = previous_record.dup
      record.assign_attributes(wpba_observation: self, evidence_source: source,
        metadata: previous_record.metadata.to_h.merge("supersedes_evidence_record_id" => previous_record.id))
      record.save!
    end
  end

  def notify_student_when_submitted
    return unless submitted? && (previously_new_record? || saved_change_to_status?)

    Notification.notify!(recipient: student, sender: observer, notifiable: self,
      title: "Observasi WPBA baru: #{wpba_instrument_version.wpba_instrument.name}",
      message: activity_summary.presence || "Observasi workplace-based assessment telah dikirim.")
  end
end
