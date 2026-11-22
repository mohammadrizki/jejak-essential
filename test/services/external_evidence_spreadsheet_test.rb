require "test_helper"

class ExternalEvidenceSpreadsheetTest < ActiveSupport::TestCase
  test "membaca worksheet pertama, teks inline dan tanggal Excel menjadi tabel kanonik" do
    csv = ExternalEvidenceSpreadsheet.new(workbook_bytes).to_csv
    table = CSV.parse(csv, headers: true)

    assert_equal "task-1", table.first["source_record_id"]
    assert_equal "Mahasiswa, Klinik", table.first["feedback"]
    assert_equal (Date.new(1899, 12, 30) + 46_300).iso8601, table.first["occurred_on"]
    assert_equal "{\"attempt\":1}", table.first["metadata_json"]
  end

  test "menolak workbook XLSX yang melampaui batas ukuran upload" do
    assert_raises(ArgumentError) do
      ExternalEvidenceSpreadsheet.new("x" * (ExternalEvidenceSpreadsheet::MAX_EXPANDED_BYTES + 1)).to_csv
    end
  end

  test "menolak koordinat sel di luar batas kolom" do
    spreadsheet = ExternalEvidenceSpreadsheet.new("placeholder")

    assert_raises(ArgumentError) { spreadsheet.send(:column_index, "XFD1") }
  end

  private

  def workbook_bytes
    headers = ExternalEvidenceCsvImport::REQUIRED_HEADERS + %w[instrument_code instrument_version score result feedback context_json metadata_json]
    values = %w[task-1 r1 activity-1 STUDENT-1 1 nil]
    columns = (1..headers.length).map { |index| column_name(index) }
    bytes = Zip::OutputStream.write_buffer do |zip|
      put(zip, "xl/workbook.xml", <<~XML)
        <?xml version="1.0" encoding="UTF-8"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets><sheet name="Evidence" sheetId="1" r:id="rId1"/></sheets>
        </workbook>
      XML
      put(zip, "xl/_rels/workbook.xml.rels", <<~XML)
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Target="worksheets/sheet1.xml" Type="worksheet"/></Relationships>
      XML
      put(zip, "xl/styles.xml", <<~XML)
        <?xml version="1.0" encoding="UTF-8"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <numFmts count="1"><numFmt numFmtId="164" formatCode="yyyy-mm-dd"/></numFmts>
          <cellXfs count="2"><xf numFmtId="0"/><xf numFmtId="164" applyNumberFormat="1"/></cellXfs>
        </styleSheet>
      XML

      rows_xml = +""
      rows_xml << "<row r=\"1\">#{headers.each_with_index.map { |header, i| inline_cell(columns[i], 1, header) }.join}</row>"
      row_values = values + ["Assignment", "2026-A", "90", "pass", "Mahasiswa, Klinik", "{}", "{\"attempt\":1}"]
      rows_xml << "<row r=\"2\">#{row_values.each_with_index.filter_map do |value, i|
        next if value.nil?
        i == 5 ? "<c r=\"#{columns[i]}2\" s=\"1\"><v>46300</v></c>" : inline_cell(columns[i], 2, value)
      end.join}</row>"
      put(zip, "xl/worksheets/sheet1.xml", "<?xml version=\"1.0\"?><worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData>#{rows_xml}</sheetData></worksheet>")
    end
    bytes.string
  end

  def put(zip, path, content)
    zip.put_next_entry(path)
    zip.write(content)
  end

  def inline_cell(column, row, value)
    "<c r=\"#{column}#{row}\" t=\"inlineStr\"><is><t>#{CGI.escapeHTML(value.to_s)}</t></is></c>"
  end

  def column_name(index)
    name = +""
    while index.positive?
      index, remainder = (index - 1).divmod(26)
      name.prepend((65 + remainder).chr)
    end
    name
  end
end
