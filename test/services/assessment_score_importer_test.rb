require "test_helper"

class AssessmentScoreImporterTest < ActiveSupport::TestCase
  test "tanggal di berkas impor disimpan sebagai pelaksanaan, bukan waktu nilai dicatat" do
    event = assessment_events(:cbt_blok)
    performed_on = 3.days.ago.to_date
    csv = "email,score,attempt,date\n#{users(:siti).email},74,1,#{performed_on.iso8601}\n"

    result = AssessmentScoreImporter.new(event: event, csv_text: csv,
      mapping: { email: "email", score: "score", attempt: "attempt", date: "date" }).call
    instance = event.assessment_instances.find_by!(student: users(:siti), attempt_number: 1)

    assert_equal 1, result.updated, result.inspect
    assert_equal performed_on, instance.performed_at.to_date
    assert_operator instance.scored_at, :>=, 1.minute.ago
    assert_not_equal instance.performed_at.to_date, instance.scored_at.to_date
  end
end
