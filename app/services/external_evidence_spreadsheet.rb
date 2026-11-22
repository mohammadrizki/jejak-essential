# frozen_string_literal: true

require "csv"
require "date"
require "rexml/document"
require "stringio"
require "zip"

# Converts the first worksheet in a plain XLSX workbook to the same tabular
# contract consumed by ExternalEvidenceCsvImport. It reads entries in place,
# never extracts the archive, and bounds both the compressed upload and the
# uncompressed XML to reduce ZIP-bomb exposure.
class ExternalEvidenceSpreadsheet
  MAX_ARCHIVE_ENTRIES = 1_000
  MAX_EXPANDED_BYTES = 20.megabytes
  MAX_COLUMNS = 128
  DATE_FORMAT_IDS = (14..22).to_a + (27..36).to_a + (45..47).to_a + (50..58).to_a
  DATE_FORMAT_PATTERN = /(?:^|[^a-z])[dmy]+(?:[^a-z]|$)/i

  def initialize(bytes)
    @bytes = bytes.to_s.b
  end

  def to_csv
    raise ArgumentError, "Workbook XLSX kosong atau terlalu besar." if @bytes.empty? || @bytes.bytesize > ExternalEvidenceCsvImport::MAX_BYTES

    csv = nil
    Zip::File.open_buffer(StringIO.new(@bytes)) do |zip|
      @expanded_read = 0
      entries = zip.entries
      raise ArgumentError, "Workbook XLSX tidak valid." if entries.empty? || entries.size > MAX_ARCHIVE_ENTRIES
      expanded_bytes = entries.sum(&:size)
      raise ArgumentError, "Ukuran isi workbook XLSX melebihi batas." if expanded_bytes > MAX_EXPANDED_BYTES

      sheet_path = first_sheet_path(zip)
      sheet_xml = read_xml_entry(zip, sheet_path)
      shared_strings = shared_strings_for(zip)
      date_styles = date_style_indexes(zip)
      rows = worksheet_rows(sheet_xml, shared_strings, date_styles)
      raise ArgumentError, "Worksheet XLSX kosong." if rows.empty?

      csv = CSV.generate { |output| rows.each { |row| output << row } }
    end
    csv
  rescue Zip::Error, REXML::ParseException, IOError, TypeError => error
    raise ArgumentError, "Workbook XLSX tidak dapat dibaca: #{error.message}"
  end

  private

  def first_sheet_path(zip)
    workbook = read_xml_entry(zip, "xl/workbook.xml")
    workbook_properties = elements_named(workbook.root, "workbookPr").first
    @date1904 = %w[1 true].include?(workbook_properties&.attributes&.[]("date1904").to_s.downcase)
    sheet = elements_named(workbook.root, "sheet").first
    raise ArgumentError, "Workbook XLSX tidak memiliki worksheet." unless sheet

    relationship_id = sheet.attributes.find { |name, _| name.split(":").last == "id" }&.last
    relationships = read_xml_entry(zip, "xl/_rels/workbook.xml.rels")
    relationship = elements_named(relationships.root, "Relationship").find do |element|
      element.attributes["Id"] == relationship_id
    end
    target = relationship&.attributes&.[]("Target")
    raise ArgumentError, "Lokasi worksheet XLSX tidak valid." if target.blank? || target.start_with?("/")

    path = File.expand_path(target, "/xl").delete_prefix("/")
    raise ArgumentError, "Lokasi worksheet XLSX tidak valid." unless path.start_with?("xl/worksheets/")
    raise ArgumentError, "Worksheet XLSX tidak ditemukan." unless zip.find_entry(path)

    path
  end

  def shared_strings_for(zip)
    entry = zip.find_entry("xl/sharedStrings.xml")
    return [] unless entry

    document = parse_xml(read_entry(entry))
    elements_named(document.root, "si").map do |item|
      elements_named(item, "t").map(&:text).join
    end
  end

  def date_style_indexes(zip)
    entry = zip.find_entry("xl/styles.xml")
    return [] unless entry

    document = parse_xml(read_entry(entry))
    custom_formats = elements_named(document.root, "numFmt").to_h do |format|
      [format.attributes["numFmtId"].to_i, format.attributes["formatCode"].to_s]
    end
    xfs = elements_named(document.root, "cellXfs").first
    return [] unless xfs

    xfs.elements.to_a.map.with_index do |xf, index|
      format_id = xf.attributes["numFmtId"].to_i
      index if DATE_FORMAT_IDS.include?(format_id) || custom_formats[format_id]&.match?(DATE_FORMAT_PATTERN)
    end.compact
  end

  def worksheet_rows(xml, shared_strings, date_styles)
    document = parse_xml(xml)
    sheet_data = elements_named(document.root, "sheetData").first
    raise ArgumentError, "Worksheet XLSX tidak memiliki data." unless sheet_data

    worksheet_elements = elements_named(sheet_data, "row")
    if worksheet_elements.size > ExternalEvidenceCsvImport::MAX_ROWS + 1
      raise ArgumentError, "Berkas melebihi batas #{ExternalEvidenceCsvImport::MAX_ROWS} baris."
    end

    rows = worksheet_elements.map do |row|
      cells = elements_named(row, "c")
      values = cells.to_h do |cell|
        [column_index(cell.attributes["r"]), cell_value(cell, shared_strings, date_styles)]
      end
      max_column = values.keys.max || 0
      (1..max_column).map { |index| values[index].to_s }
    end
    rows.reject { |row| row.all?(&:blank?) }
  end

  def cell_value(cell, shared_strings, date_styles)
    type = cell.attributes["t"]
    value_node = elements_named(cell, "v").first
    raw = case type
    when "inlineStr" then elements_named(cell, "t").map(&:text).join
    when "s" then shared_strings.fetch(value_node&.text.to_i, "")
    when "b" then value_node&.text == "1" ? "TRUE" : "FALSE"
    else value_node&.text.to_s
    end
    return raw unless type.nil? && date_styles.include?(cell.attributes["s"].to_i) && raw.present?

    serial = Float(raw)
    raise ArgumentError, "Tanggal XLSX di luar rentang yang didukung." unless serial.finite? && serial >= 0 && serial < 2_958_466

    origin = @date1904 ? Date.new(1904, 1, 1) : Date.new(1899, 12, 30)
    (origin + serial.floor).iso8601
  rescue ArgumentError, TypeError
    raise ArgumentError, "Nilai tanggal XLSX tidak valid."
  end

  def column_index(reference)
    letters = reference.to_s[/\A[A-Z]+/]
    raise ArgumentError, "Referensi sel XLSX tidak valid." unless letters

    index = letters.each_char.reduce(0) { |value, letter| value * 26 + letter.ord - 64 }
    raise ArgumentError, "Worksheet XLSX melebihi batas #{MAX_COLUMNS} kolom." if index > MAX_COLUMNS

    index
  end

  def read_xml_entry(zip, path)
    entry = zip.find_entry(path)
    raise ArgumentError, "Struktur workbook XLSX tidak lengkap (#{path})." unless entry

    parse_xml(read_entry(entry))
  end

  def read_entry(entry)
    stream = entry.get_input_stream
    contents = stream.read(MAX_EXPANDED_BYTES + 1)
    raise ArgumentError, "Ukuran XML workbook XLSX melebihi batas." if contents.bytesize > MAX_EXPANDED_BYTES
    @expanded_read += contents.bytesize
    raise ArgumentError, "Ukuran isi workbook XLSX melebihi batas." if @expanded_read > MAX_EXPANDED_BYTES

    contents
  ensure
    stream&.close
  end

  def parse_xml(xml)
    return xml if xml.is_a?(REXML::Document)
    raise ArgumentError, "Deklarasi entity XML tidak didukung." if xml.match?(/<!DOCTYPE|<!ENTITY/i)

    REXML::Document.new(xml)
  end

  def elements_named(element, name)
    return [] unless element
    return [element] if element.name == name

    element.elements.flat_map { |child| elements_named(child, name) }
  end
end
