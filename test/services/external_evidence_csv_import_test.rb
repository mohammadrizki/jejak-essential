require "test_helper"

class ExternalEvidenceCsvImportTest < ActiveSupport::TestCase
  setup do
    @student = users(:siti)
    @program = @student.study_program
    @actor = users(:dedi)
    ModuleConfiguration.for(@program).update!({ "integration_moodle" => true }, actor: @actor)
    @requirement = EvidenceRequirement.create!(origin: "manual", competency_item: competency_items(:sub_anamnesis),
      source_type: "external", required_count: 1)
    ExternalIdentityResolver.map_student!(source_system: "moodle", external_id: "M-009", student: @student, by: @actor)
    @csv = <<~CSV
      source_record_id,source_revision,activity_key,student_external_id,requirement_id,occurred_on,instrument_code,instrument_version,score,result,feedback,context_json,metadata_json
      task-009,r1,assignment-009-siti,M-009,#{@requirement.id},2026-11-21,Assignment,2026-A,90,pass,Memenuhi target,"{""course"":""Klinik""}","{""attempt"":1}"
    CSV
  end

  test "pratinjau tidak menulis bukti dan impor idempoten mempertahankan status belum tervalidasi" do
    importer = importer_for(@csv)
    preview = importer.preview
    assert preview.valid?
    assert_equal 1, preview.imported_count
    assert_no_difference "EvidenceSource.count" do
      # Parsing and matching are read-only.
      importer.preview
    end

    batch = batch_for(preview)
    importer.import!(batch: batch, confirmed_sha256: preview.sha256)
    assert_equal "imported", batch.reload.status
    source = EvidenceSource.find_by!(source_system: "moodle", source_record_id: "task-009", source_revision: "r1")
    assert_equal "unverified", source.validation_status
    assert_equal batch.id, source.metadata["jejak_import_batch_id"]
    assert_equal @actor.id, source.metadata["jejak_imported_by_id"]
    assert_equal 1, @requirement.evidence_records.count

    next_preview = importer.preview
    next_batch = batch_for(next_preview)
    importer.import!(batch: next_batch, confirmed_sha256: next_preview.sha256)
    assert_equal 1, EvidenceSource.where(source_system: "moodle", source_record_id: "task-009").count
    assert_equal batch.id, source.reload.metadata["jejak_import_batch_id"]
    assert_equal 1, @requirement.evidence_records.count
  end

  test "baris tidak valid menghentikan seluruh batch" do
    csv = @csv.sub("2026-11-21", "not-a-date")
    preview = importer_for(csv).preview
    assert_not preview.valid?
    assert_match "occurred_on harus tanggal ISO-8601", preview.errors.join(" ")
    assert_no_difference "EvidenceSource.count" do
      assert_no_difference "EvidenceRecord.count" do
        assert_raises(ArgumentError) do
          importer_for(csv).import!(batch: batch_for(preview), confirmed_sha256: preview.sha256)
        end
      end
    end
  end

  test "konfirmasi menolak file berbeda dari yang dipratinjau" do
    preview = importer_for(@csv).preview
    batch = batch_for(preview)
    assert_raises(ArgumentError) do
      importer_for(@csv.sub("Memenuhi target", "Payload lain")).import!(batch: batch, confirmed_sha256: preview.sha256)
    end
    assert_equal "previewed", batch.reload.status
  end

  test "galat pada baris berikutnya me-rollback seluruh batch dan menyimpan audit kegagalan" do
    duplicate_conflict = @csv.sub("Memenuhi target", "Nilai berubah untuk revision yang sama")
    combined = @csv.lines.first + @csv.lines.second + duplicate_conflict.lines.second
    preview = importer_for(combined).preview
    batch = batch_for(preview)

    assert_no_difference "EvidenceSource.count" do
      assert_no_difference "EvidenceRecord.count" do
        assert_raises(ArgumentError) do
          importer_for(combined).import!(batch: batch, confirmed_sha256: preview.sha256)
        end
      end
    end
    assert_equal "failed", batch.reload.status
    assert_equal 0, batch.imported_count
    assert batch.row_results.any? { |row| row["errors"]&.any? { |message| message.include?("payload yang berbeda") } }
  end

  private

  def importer_for(csv)
    ExternalEvidenceCsvImport.new(study_program: @program, source_system: "moodle", csv_text: csv, actor: @actor)
  end

  def batch_for(preview)
    ExternalImportBatch.create!(study_program: @program, uploaded_by: @actor, source_system: "moodle",
      filename: "hasil.csv", file_sha256: preview.sha256, row_count: preview.rows.length,
      row_results: preview.rows.map { |row| { "row" => row.number, "status" => row.errors.empty? ? "ready" : "invalid", "errors" => row.errors } })
  end
end
