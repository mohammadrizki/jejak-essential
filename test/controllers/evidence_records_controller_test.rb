require "test_helper"

class EvidenceRecordsControllerTest < ActiveSupport::TestCase
  test "bukti WPBA menerima assessment instance hanya untuk CBD" do
    assessment_record = Struct.new(:assessment_event).new(Struct.new(:assessment_type).new("cbd"))
    controller = EvidenceRecordsController.new

    assert controller.send(:source_matches_requirement?, :assessment_instance, assessment_record, "wpba")

    assessment_record.assessment_event.assessment_type = "cbt"
    assert_not controller.send(:source_matches_requirement?, :assessment_instance, assessment_record, "wpba")
  end
end
