require "test_helper"

class CompetencyAttainmentTest < ActiveSupport::TestCase
  test "approval is an explicit immutable review separate from evidence sufficiency" do
    student = users(:siti)
    item = competency_items(:domain_klinis)
    snapshot = CompetencyAttainmentSnapshot.capture(student: student, competency_item: item)
    assert_equal item.competency_framework_id, snapshot.fetch("framework_id")
    assert_equal [], snapshot.fetch("requirements")

    attainment = CompetencyAttainment.create!(student: student, competency_item: item,
      decision_by: users(:budi), attainment_level: 3, decision_date: Time.current,
      status: "proposed", framework_version: item.competency_framework.version,
      evidence_snapshot: snapshot, rationale: "Usulan berdasarkan bukti terkurasi.")

    assert_equal "proposed", attainment.status
    attainment.review!(by: users(:dedi), decision: "approved", notes: "Bukti dan perkembangan memadai.")

    assert_equal "approved", attainment.reload.status
    assert_equal users(:dedi), attainment.reviewed_by
    assert_equal 1, attainment.reviews.count
    assert_raises(ActiveRecord::RecordNotSaved) { attainment.update!(review_notes: "diubah") }
  end
end
