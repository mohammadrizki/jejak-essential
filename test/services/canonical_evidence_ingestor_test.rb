require "test_helper"

class CanonicalEvidenceIngestorTest < ActiveSupport::TestCase
  def setup
    @student = users(:siti)
    item = competency_items(:sub_anamnesis)
    @requirement = EvidenceRequirement.create!(origin: "manual", competency_item: item,
      source_type: "external", required_count: 1)
  end

  test "repeated delivery of the same revision is idempotent" do
    first = ingestor.call.evidence_source
    second = ingestor.call.evidence_source

    assert_equal first.id, second.id
    assert_equal 1, EvidenceSource.where(source_system: "examtool-test", source_record_id: "exam-42").count
    assert_equal 1, @requirement.evidence_records.count
    assert_equal :in_progress, EvidenceRequirementProgress.new(@requirement).call.status
  end

  test "the same revision identifier cannot be reused with changed data" do
    ingestor.call
    changed = ingestor(payload: { "score" => 91 })

    assert_raises(ArgumentError) { changed.call }
  end

  test "a correction revision replaces the earlier revision for sufficiency" do
    old_source = ingestor.call.evidence_source
    old_source.validate_source!(by: users(:budi))
    assert_equal :fulfilled, EvidenceRequirementProgress.new(@requirement).call.status

    newer = ingestor(payload: { "source_revision" => "revision-b", "score" => 78 }).call.evidence_source
    progress = EvidenceRequirementProgress.new(@requirement).call
    assert_equal :in_progress, progress.status
    assert_equal 0, progress.record_count

    newer.validate_source!(by: users(:budi))
    progress = EvidenceRequirementProgress.new(@requirement).call
    assert_equal :fulfilled, progress.status
    assert_equal 1, progress.record_count
  end

  private

  def ingestor(payload: {})
    base = {
      "source_record_id" => "exam-42", "source_revision" => "revision-a",
      "activity_key" => "exam:semester-1:student-#{@student.id}", "student" => @student,
      "occurred_on" => Date.current.iso8601, "instrument_code" => "MCQ-FINAL",
      "instrument_version" => "2026.1", "score" => 84, "result" => "pass",
      "feedback" => "Domain hasil tersedia", "context" => { "course" => "Kardiologi" },
      "metadata" => { "finalized" => true }
    }
    CanonicalEvidenceIngestor.new(source_system: "examtool-test", payload: base.merge(payload),
      requirement: @requirement)
  end
end
