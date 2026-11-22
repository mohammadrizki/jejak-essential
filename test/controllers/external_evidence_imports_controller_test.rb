require "test_helper"
require "csv"
require "cgi"
require "digest"
require "zip"

class ExternalEvidenceImportsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @student = users(:siti)
    @program = @student.study_program
    @manager = users(:dedi)
    ModuleConfiguration.for(@program).update!({ "integration_moodle" => true }, actor: @manager)
    @requirement = EvidenceRequirement.create!(origin: "manual", competency_item: competency_items(:sub_anamnesis),
      source_type: "external", required_count: 1)
    ExternalIdentityResolver.map_student!(source_system: "moodle", external_id: "M-IMPORT", student: @student, by: @manager)
    @csv = CSV.generate do |rows|
      rows << ExternalEvidenceCsvImport::REQUIRED_HEADERS + %w[result]
      rows << ["activity-1", "v1", "activity-1-siti", "M-IMPORT", @requirement.id, "2026-11-22", "pass"]
    end
  end

  test "Kaprodi pratinjau lalu mengonfirmasi file yang sama dan hanya membuat evidence unverified" do
    sign_in @manager
    upload = ->(content) { Rack::Test::UploadedFile.new(StringIO.new(content), "text/csv", original_filename: "hasil.csv") }

    assert_no_difference "EvidenceRecord.count" do
      post external_evidence_imports_path, params: { stage: "preview", source_system: "moodle",
        study_program_id: @program.id, csv_file: upload.call(@csv) }
    end
    assert_response :success
    assert_match "Semua baris lolos validasi awal", response.body
    batch = ExternalImportBatch.last
    assert_equal "previewed", batch.status

    post external_evidence_imports_path, params: { stage: "import", source_system: "moodle",
      study_program_id: @program.id, batch_id: batch.id, file_sha256: batch.file_sha256, csv_file: upload.call(@csv) }
    assert_redirected_to external_evidence_import_path(batch)
    assert_equal "imported", batch.reload.status
    assert_equal "unverified", EvidenceSource.find_by!(source_record_id: "activity-1").validation_status
  end

  test "Kaprodi dapat mempratinjau dan mengonfirmasi XLSX dengan hash file asli" do
    sign_in @manager
    bytes = xlsx_bytes(CSV.parse(@csv, headers: true).first.fields)
    upload = -> { Rack::Test::UploadedFile.new(StringIO.new(bytes),
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", original_filename: "hasil.xlsx") }

    assert_no_difference "EvidenceRecord.count" do
      post external_evidence_imports_path, params: { stage: "preview", source_system: "moodle",
        study_program_id: @program.id, csv_file: upload.call }
    end
    assert_response :success, response.body
    batch = ExternalImportBatch.last
    assert_equal Digest::SHA256.hexdigest(bytes), batch.file_sha256

    post external_evidence_imports_path, params: { stage: "import", source_system: "moodle",
      study_program_id: @program.id, batch_id: batch.id, file_sha256: batch.file_sha256, csv_file: upload.call }
    assert_redirected_to external_evidence_import_path(batch)
    assert_equal "imported", batch.reload.status
    assert_equal "unverified", EvidenceSource.find_by!(source_record_id: "activity-1").validation_status
  end

  test "adapter WPBA klinis eksternal mengimpor Syarat Bukti EPA melalui pratinjau dan konfirmasi" do
    admin = users(:budi)
    admin.roles << roles(:admin)
    program = study_programs(:profesi_dokter)
    student = User.create!(full_name: "Mahasiswa EPA Impor", email: "epa-import-student@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: program)
    student.roles << roles(:mahasiswa)
    framework = CompetencyFramework.create!(study_program: program,
      name: "Framework Impor EPA", version: "1", education_stage: "profesi")
    epa = framework.epas.create!(code: "EPA-IMPORT", title: "Melakukan asesmen klinis")
    requirement = EvidenceRequirement.create!(epa: epa, origin: "manual", source_type: "external", required_count: 1)
    ModuleConfiguration.for(program).update!({ wpba: "0", integration_clinical_wpba: "1" }, actor: admin)
    ExternalIdentityResolver.map_student!(source_system: "clinical_wpba", external_id: "WPBA-EXT-01",
      student: student, by: admin, authority: "integration")
    csv = CSV.generate do |rows|
      rows << ExternalEvidenceCsvImport::REQUIRED_HEADERS + %w[result context_json]
      rows << ["epa-observation-01", "r1", "epa-activity-01", "WPBA-EXT-01", requirement.id,
        Date.current.iso8601, "pass", "{\"supervision\":\"direct\"}"]
    end
    upload = -> { Rack::Test::UploadedFile.new(StringIO.new(csv), "text/csv", original_filename: "wpba-epa.csv") }
    sign_in admin

    get new_external_evidence_import_path(study_program_id: program.id)
    assert_select "select[name=source_system] option[value=clinical_wpba]", 1
    assert_no_difference "EvidenceSource.count" do
      post external_evidence_imports_path, params: { stage: "preview", source_system: "clinical_wpba",
        study_program_id: program.id, csv_file: upload.call }
    end
    assert_response :success, response.body
    batch = ExternalImportBatch.last
    assert_equal "previewed", batch.status

    post external_evidence_imports_path, params: { stage: "import", source_system: "clinical_wpba",
      study_program_id: program.id, batch_id: batch.id, file_sha256: batch.file_sha256, csv_file: upload.call }
    assert_redirected_to external_evidence_import_path(batch)
    source = EvidenceSource.find_by!(source_system: "clinical_wpba", source_record_id: "epa-observation-01")
    assert_equal "unverified", source.validation_status
    assert_equal 1, requirement.evidence_records.where(evidence_source: source).count
  end

  test "Kaprodi tidak dapat memilih program studi lain atau membuka batch lintas program" do
    sign_in @manager
    other_program = study_programs(:profesi_dokter)
    get new_external_evidence_import_path(study_program_id: other_program.id)
    assert_response :success
    assert_select "select[name=study_program_id] option[value='#{other_program.id}']", count: 0

    other_batch = ExternalImportBatch.create!(study_program: other_program, uploaded_by: users(:budi),
      source_system: "moodle", filename: "other.csv", file_sha256: "a" * 64, row_count: 0, row_results: [])
    get external_evidence_import_path(other_batch)
    assert_response :not_found
  end

  test "mahasiswa tidak boleh membuka endpoint impor" do
    sign_in @student
    get external_evidence_imports_path
    assert_redirected_to dashboard_path
  end

  test "tenaga kependidikan hanya dapat mengimpor dan memetakan data untuk program studi yang ditugaskan" do
    staff = User.create!(full_name: "Petugas Data", email: "petugas-impor@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: @program,
      active_role: roles(:tenaga_kependidikan))
    staff.roles << roles(:tenaga_kependidikan)
    UserAssignment.create!(user: staff, assigned_by: @manager, study_program: @program,
      assignment_role: "external_data_manager", scope_type: "StudyProgram", scope_id: @program.id,
      reason: "Ditugaskan menangani rekonsiliasi dan impor data sumber semester ini.")
    sign_in staff

    get external_evidence_imports_path
    assert_response :success
    get new_external_evidence_import_path(study_program_id: study_programs(:profesi_dokter).id)
    assert_response :not_found
    get new_external_evidence_import_path(study_program_id: @program.id)
    assert_response :success
    get external_identity_mappings_path
    assert_response :success
    assert_select "select[name='external_identity_mapping[student_id]'] option[value='#{users(:budi).id}']", count: 0
  end

  test "tenaga kependidikan tanpa penugasan tidak dapat membuka fungsi integrasi" do
    staff = User.create!(full_name: "Petugas Tanpa Tugas", email: "petugas-tanpa-tugas@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: @program,
      active_role: roles(:tenaga_kependidikan))
    staff.roles << roles(:tenaga_kependidikan)
    sign_in staff

    get external_evidence_imports_path
    assert_redirected_to dashboard_path
    get external_identity_mappings_path
    assert_redirected_to dashboard_path
  end

  private

  def xlsx_bytes(values)
    headers = CSV.parse(@csv, headers: true).headers
    columns = (1..headers.length).map { |index| spreadsheet_column(index) }
    workbook = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry("xl/workbook.xml")
      zip.write('<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Evidence" sheetId="1" r:id="rId1"/></sheets></workbook>')
      zip.put_next_entry("xl/_rels/workbook.xml.rels")
      zip.write('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Target="worksheets/sheet1.xml" Type="worksheet"/></Relationships>')
      zip.put_next_entry("xl/worksheets/sheet1.xml")
      header_cells = headers.each_with_index.map { |value, index| spreadsheet_cell(columns[index], 1, value) }.join
      value_cells = values.each_with_index.map { |value, index| spreadsheet_cell(columns[index], 2, value) }.join
      zip.write("<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData><row r=\"1\">#{header_cells}</row><row r=\"2\">#{value_cells}</row></sheetData></worksheet>")
    end
    workbook.string
  end

  def spreadsheet_cell(column, row, value)
    "<c r=\"#{column}#{row}\" t=\"inlineStr\"><is><t>#{CGI.escapeHTML(value.to_s)}</t></is></c>"
  end

  def spreadsheet_column(index)
    name = +""
    while index.positive?
      index, remainder = (index - 1).divmod(26)
      name.prepend((65 + remainder).chr)
    end
    name
  end
end
