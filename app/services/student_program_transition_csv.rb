# frozen_string_literal: true

require "csv"

# Preview-first CSV intake for graduation and proposed transfers. Graduation is
# decided in the source program; a transfer remains pending until its target
# program accepts it. No CSV row changes User#study_program_id directly.
class StudentProgramTransitionCsv
  class Error < StandardError; end
  MODES = %w[graduate transfer].freeze
  MAX_ROWS = 2000
  ALIASES = {
    identifier: %w[email e_mail surel identifier npm nim],
    destination_identifier: %w[npm_tujuan npm_baru destination_npm],
    cohort_year: %w[angkatan angkatan_tujuan cohort_year],
    completed_on: %w[tanggal_lulus completed_on]
  }.freeze

  Match = Struct.new(:line, :identifier, :user, :enrollment, :destination_identifier,
    :cohort_year, :completed_on, :note, keyword_init: true) do
    def eligible? = note == "siap"
  end
  Result = Struct.new(:processed, :skipped, keyword_init: true)

  def initialize(csv:, mode:, source_program:, actor:, destination_program: nil, completed_on: nil)
    raise Error, "Aksi tidak valid." unless MODES.include?(mode.to_s)
    raise Error, "Program studi asal wajib dipilih." if source_program.blank?
    raise Error, "Program studi tujuan wajib dipilih untuk transfer." if mode.to_s == "transfer" && destination_program.blank?

    @csv = csv.to_s.dup.force_encoding("UTF-8").scrub("").delete_prefix("﻿")
    @mode = mode.to_s
    @source = source_program
    @destination = destination_program
    @actor = actor
    @completed_on = parse_date(completed_on) if completed_on.present?
  end

  def matches
    @matches ||= resolve(parse_rows)
  end

  def apply!
    eligible = matches.select(&:eligible?)
    StudentProgramEnrollment.transaction do
      eligible.each do |match|
        match.enrollment.lock!
        if @mode == "graduate"
          StudentTransferWorkflow.new.graduate!(enrollment: match.enrollment, by: @actor,
            completed_on: match.completed_on || @completed_on || Date.current,
            reason: "Penetapan kelulusan melalui impor CSV.")
        else
          StudentTransferWorkflow.new.request_transfer!(source_enrollment: match.enrollment,
            destination_study_program: @destination, by: @actor,
            destination_identifier_number: match.destination_identifier,
            destination_cohort_year: match.cohort_year)
        end
      end
    end
    Result.new(processed: eligible.length, skipped: matches.length - eligible.length)
  rescue ActiveRecord::RecordNotUnique
    raise Error, "Data berubah setelah pratinjau. Muat ulang pratinjau sebelum menerapkan."
  end

  private

  def parse_rows
    return [] if @csv.strip.empty?

    separator = @csv.lines.first.to_s.count(";") > @csv.lines.first.to_s.count(",") ? ";" : ","
    rows = CSV.parse(@csv, headers: true, col_sep: separator,
      header_converters: ->(header) { header.to_s.strip.downcase.gsub(/[\s-]+/, "_") })
    identifier_columns = rows.headers.select { |header| ALIASES[:identifier].include?(header) }
    columns = ALIASES.except(:identifier).transform_values { |names| rows.headers.find { |header| names.include?(header) } }
    raise Error, "Kolom email/NPM/NIM wajib ada pada CSV." if identifier_columns.empty?

    parsed = rows.each.with_index(2).filter_map do |row, line|
      identifier = identifier_columns.map { |column| row[column].to_s.strip }.find(&:present?).to_s
      next if identifier.blank?

      { line: line, identifier: identifier,
        destination_identifier: columns[:destination_identifier] ? row[columns[:destination_identifier]].to_s.strip.presence : nil,
        cohort_year: columns[:cohort_year] ? parse_year(row[columns[:cohort_year]]) : nil,
        raw_cohort_year: columns[:cohort_year] ? row[columns[:cohort_year]].to_s.strip : nil,
        completed_on: columns[:completed_on] ? parse_date(row[columns[:completed_on]]) : nil,
        raw_completed_on: columns[:completed_on] ? row[columns[:completed_on]].to_s.strip : nil }
    end
    raise Error, "CSV melebihi batas #{MAX_ROWS} baris." if parsed.length > MAX_ROWS

    parsed
  rescue CSV::MalformedCSVError => error
    raise Error, "CSV tidak dapat dibaca: #{error.message}"
  end

  def resolve(rows)
    emails = rows.filter_map { |row| row[:identifier].downcase if row[:identifier].include?("@") }.uniq
    identifiers = rows.filter_map { |row| row[:identifier] unless row[:identifier].include?("@") }.uniq
    users = User.joins(:roles).where(roles: { code: "mahasiswa" }).distinct
    by_email = emails.empty? ? {} : users.where("LOWER(users.email) IN (?)", emails).index_by { |user| user.email.downcase }
    source_enrollments = if identifiers.empty?
      StudentProgramEnrollment.none
    else
      StudentProgramEnrollment.where(study_program: @source, identifier_number: identifiers).includes(:user)
    end
    by_identifier = source_enrollments.group_by(&:identifier_number).transform_values { |rows| rows.map(&:user).uniq(&:id) }
    seen = rows.map { |row| row[:identifier].include?("@") ? row[:identifier].downcase : row[:identifier] }.tally
    candidates = rows.map do |row|
      found = row[:identifier].include?("@") ? Array(by_email[row[:identifier].downcase]) : Array(by_identifier[row[:identifier]])
      found
    end
    user_counts = candidates.filter_map { |found| found.first.id if found.one? }.tally

    rows.zip(candidates).map do |row, found|
      user = found.one? ? found.first : nil
      enrollment = user && StudentProgramEnrollment.find_by(user: user, study_program: @source,
        status: @mode == "graduate" ? "active" : "graduated")
      match = Match.new(line: row[:line], identifier: row[:identifier], user: user, enrollment: enrollment,
        destination_identifier: row[:destination_identifier], cohort_year: row[:cohort_year],
        completed_on: row[:completed_on])
      match.note = note_for(match, found, row, seen, user_counts)
      match
    end
  end

  def note_for(match, found, row, seen, user_counts)
    return "tidak ditemukan" if found.empty?
    return "identifier cocok ke lebih dari satu akun" if found.length > 1
    normalized_identifier = row[:identifier].include?("@") ? row[:identifier].downcase : row[:identifier]
    return "akun yang sama muncul beberapa kali" if seen[normalized_identifier] > 1 || user_counts[match.user.id] > 1
    return "tidak ada keanggotaan prodi asal yang sesuai" if match.enrollment.blank?
    return "keanggotaan asal bukan status lulus" if @mode == "transfer" && !match.enrollment.graduated?
    return "mahasiswa sudah memiliki permintaan transfer aktif" if @mode == "transfer" &&
      StudentProgramTransfer.pending.exists?(source_enrollment: match.enrollment)
    return "prodi tujuan harus berbeda dari prodi asal" if @mode == "transfer" && @destination.id == @source.id
    return "format angkatan tujuan tidak valid" if row[:raw_cohort_year].present? && match.cohort_year.nil?
    return "format tanggal lulus tidak valid" if @mode == "graduate" && row[:raw_completed_on].present? && match.completed_on.nil?
    target_identifier = match.destination_identifier.presence || match.user&.identifier_number
    return "NPM/NIM tujuan sudah digunakan di prodi tujuan" if @mode == "transfer" && target_identifier.present? &&
      StudentProgramEnrollment.exists?(study_program: @destination, identifier_number: target_identifier)

    "siap"
  end

  def parse_year(value)
    match = value.to_s.strip.match(/\A(\d{4})(?:\.0+)?\z/)
    year = match && match[1].to_i
    year if year && year > 1950 && year <= Date.current.year + 1
  end

  def parse_date(value)
    Date.iso8601(value.to_s.strip)
  rescue Date::Error, TypeError
    nil
  end
end
