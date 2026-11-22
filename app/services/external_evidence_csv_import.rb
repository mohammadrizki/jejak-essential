# frozen_string_literal: true

require "csv"
require "digest"
require "json"

# Two-phase, program-scoped CSV bridge. Preview only resolves and validates;
# evidence and audit rows are written together after the user confirms the
# exact same file by its SHA-256 digest.
class ExternalEvidenceCsvImport
  MAX_ROWS = 2_000
  MAX_BYTES = 10.megabytes
  REQUIRED_HEADERS = %w[source_record_id source_revision activity_key student_external_id requirement_id occurred_on].freeze
  ADAPTERS = {
    "moodle" => MoodleAdapter, "examtool" => ExamtoolAdapter, "osce" => OsceAdapter,
    "clinical_wpba" => ClinicalWpbaAdapter
  }.freeze
  Row = Data.define(:number, :source_record_id, :student, :requirement, :payload, :errors)
  Preview = Data.define(:rows, :errors, :sha256) do
    def valid? = errors.empty? && rows.any? && rows.all? { |row| row.errors.empty? }
    def imported_count = rows.count { |row| row.errors.empty? }
  end

  def initialize(study_program:, source_system:, csv_text:, actor:, file_sha256: nil)
    @study_program = study_program
    @source_system = source_system.to_s
    @csv_text = csv_text.to_s
    @file_sha256 = file_sha256
    @actor = actor
  end

  def preview
    raise ArgumentError, "Sistem sumber tidak didukung." unless ADAPTERS.key?(@source_system)
    raise ArgumentError, "Adapter #{@source_system} belum diaktifkan untuk program studi ini." unless
      ModuleConfiguration.for(@study_program).enabled?("integration_#{@source_system}")
    raise ArgumentError, "Berkas CSV kosong atau lebih dari 10 MB." if @csv_text.blank? || @csv_text.bytesize > MAX_BYTES

    text = GlideCsv.read(@csv_text)
    table = GlideCsv.parse(text)
    headers = table.headers.map { |header| header.to_s.strip.downcase }
    raise ArgumentError, "Berkas memiliki nama kolom ganda." unless headers.uniq.length == headers.length
    missing = REQUIRED_HEADERS - headers
    raise ArgumentError, "Kolom wajib tidak ditemukan: #{missing.join(', ')}." if missing.any?
    raise ArgumentError, "Berkas melebihi batas #{MAX_ROWS} baris." if table.size > MAX_ROWS
    raise ArgumentError, "Berkas tidak berisi baris data." if table.empty?

    rows = table.each_with_index.map { |csv_row, index| build_row(csv_row, headers, index + 2) }
    row_errors = rows.flat_map { |row| row.errors.map { |message| "Baris #{row.number}: #{message}" } }
    Preview.new(rows, row_errors, @file_sha256 || Digest::SHA256.hexdigest(text))
  rescue CSV::MalformedCSVError => error
    raise ArgumentError, "CSV tidak dapat dibaca: #{error.message}"
  end

  def import!(batch:, confirmed_sha256:)
    verify_batch!(batch, confirmed_sha256)
    result = preview
    raise ArgumentError, "Berkas yang dipilih berbeda dari berkas pratinjau." unless
      ActiveSupport::SecurityUtils.secure_compare(batch.file_sha256, result.sha256)
    unless result.valid?
      batch.fail!(row_results: result.rows.map do |row|
        { "row" => row.number, "source_record_id" => row.source_record_id,
          "status" => "invalid", "errors" => row.errors }
      end)
      raise ArgumentError, result.errors.join(" ")
    end

    adapter = ADAPTERS.fetch(@source_system).new(study_program: @study_program)
    row_results = []
    begin
      ActiveRecord::Base.transaction do
        result.rows.each do |row|
          evidence = adapter.ingest!(payload: row.payload.merge("student" => row.student), requirement: row.requirement,
            batch: batch, actor: @actor)
          row_results << { "row" => row.number, "source_record_id" => row.source_record_id,
            "status" => "imported", "evidence_source_id" => evidence.evidence_source_id }
        end
        batch.lock!
        raise ArgumentError, "Batch impor sudah pernah diproses." unless batch.previewed?
        batch.complete!(row_results: row_results, imported_count: row_results.length)
      end
      batch
    rescue StandardError => error
      if batch.reload.previewed?
        failure_rows = result.rows.map do |row|
          { "row" => row.number, "source_record_id" => row.source_record_id,
            "status" => "failed", "errors" => row.errors }
        end
        failure_rows << { "status" => "failed", "errors" => [error.message] }
        batch.fail!(row_results: failure_rows)
      end
      raise
    end
  end

  private

  def verify_batch!(batch, confirmed_sha256)
    raise ActiveRecord::RecordNotFound unless batch.study_program_id == @study_program.id &&
      batch.source_system == @source_system && batch.uploaded_by_id == @actor&.id
    raise ArgumentError, "Isi berkas berubah sejak pratinjau; buat pratinjau baru." unless
      ActiveSupport::SecurityUtils.secure_compare(batch.file_sha256, confirmed_sha256.to_s)
    raise ArgumentError, "Batch impor sudah pernah diproses." unless batch.previewed?
  end

  def build_row(csv_row, headers, number)
    values = headers.zip(csv_row.fields).to_h
    errors = []
    source_record_id = values["source_record_id"].to_s.strip
    student = resolve_student(values["student_external_id"], errors)
    requirement = resolve_requirement(values["requirement_id"], errors)
    occurred_on = parse_date(values["occurred_on"], errors)
    errors << "source_record_id wajib diisi" if source_record_id.blank?
    errors << "source_revision wajib diisi" if values["source_revision"].blank?
    errors << "activity_key wajib diisi" if values["activity_key"].blank?

    score = parse_score(values["score"], errors)
    result = values["result"].presence || "not_assessed"
    errors << "result harus pass, fail, borderline, not_assessed, atau other" unless result.in?(EvidenceSource::RESULTS)
    context = parse_json_object(values["context_json"], "context_json", errors)
    metadata = parse_json_object(values["metadata_json"], "metadata_json", errors)
    payload = {
      "source_record_id" => source_record_id,
      "source_revision" => values["source_revision"].to_s.strip,
      "activity_key" => values["activity_key"].to_s.strip,
      "occurred_on" => occurred_on&.iso8601,
      "instrument_code" => values["instrument_code"].presence,
      "instrument_version" => values["instrument_version"].presence,
      "score" => score,
      "result" => result,
      "feedback" => values["feedback"].presence,
      "context" => context,
      "metadata" => metadata
    }.compact
    Row.new(number, source_record_id, student, requirement, payload, errors)
  end

  def resolve_student(external_id, errors)
    return errors << "student_external_id wajib diisi" if external_id.blank?

    student = ExternalIdentityResolver.resolve_student!(source_system: @source_system, external_id: external_id.to_s.strip)
    raise ActiveRecord::RecordNotFound unless student.study_program_id == @study_program.id

    student
  rescue ActiveRecord::RecordNotFound
    errors << "mahasiswa tidak ditemukan pada pemetaan sumber/program studi ini"
    nil
  end

  def resolve_requirement(id, errors)
    requirement = EvidenceRequirement.where(source_type: "external", status: "active").find_by(id: id)
    framework = requirement&.competency_item&.competency_framework || requirement&.epa&.competency_framework ||
      requirement&.blueprint_item&.blueprint_version&.competency_framework
    if requirement && framework&.study_program_id == @study_program.id
      if requirement.epa.present? && @source_system != "clinical_wpba"
        errors << "Syarat Bukti EPA eksternal hanya dapat diimpor dari sumber WPBA klinis."
      end
      return requirement
    end

    errors << "Syarat Bukti eksternal aktif tidak ditemukan pada program studi ini"
    nil
  end

  def parse_date(raw, errors)
    Date.iso8601(raw.to_s.strip)
  rescue Date::Error
    errors << "occurred_on harus tanggal ISO-8601 (YYYY-MM-DD)"
    nil
  end

  def parse_score(raw, errors)
    return if raw.blank?

    score = Float(raw.to_s.tr(",", "."))
    raise ArgumentError unless score.finite?
    score
  rescue ArgumentError, TypeError
    errors << "score harus berupa angka finite"
    nil
  end

  def parse_json_object(raw, name, errors)
    return {} if raw.blank?

    value = JSON.parse(raw)
    raise JSON::ParserError unless value.is_a?(Hash)
    value
  rescue JSON::ParserError
    errors << "#{name} harus berupa object JSON yang valid"
    {}
  end
end
