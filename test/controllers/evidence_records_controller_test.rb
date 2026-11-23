require "test_helper"

class EvidenceRecordsControllerTest < ActiveSupport::TestCase
  test "bukti WPBA menerima assessment instance hanya untuk CBD" do
    assessment_record = Struct.new(:assessment_event).new(Struct.new(:assessment_type).new("cbd"))
    controller = EvidenceRecordsController.new

    assert controller.send(:source_matches_requirement?, :assessment_instance, assessment_record, "wpba")

    assessment_record.assessment_event.assessment_type = "cbt"
    assert_not controller.send(:source_matches_requirement?, :assessment_instance, assessment_record, "wpba")
  end

  test "evidence sources kanonis dapat ditautkan ke jenis bukti yang sesuai" do
    controller = EvidenceRecordsController.new
    source = EvidenceSource.new(source_type: "external")

    assert controller.send(:source_matches_requirement?, :evidence_source, source, "external")
    assert controller.send(:source_matches_requirement?, :evidence_source, source, "portfolio")
    assert_not controller.send(:source_matches_requirement?, :evidence_source, source, "assessment")
  end

  test "observasi EPA yang aman dan evidence source EPA dapat memenuhi target EPA" do
    controller = EvidenceRecordsController.new
    observation = EpaObservation.new(status: "recorded", safety_flag: false)
    source = EvidenceSource.new(source_type: "epa_observation")

    assert controller.send(:source_matches_requirement?, :epa_observation, observation, "epa_observation")
    assert controller.send(:source_matches_requirement?, :evidence_source, source, "epa_observation")
    assert_equal "other", controller.send(:initial_result, observation)
  end
end
