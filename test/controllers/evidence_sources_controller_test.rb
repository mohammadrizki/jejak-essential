require "test_helper"

class EvidenceSourcesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @student = users(:siti)
    @program = @student.study_program
    @reviewer = users(:dedi)
    @requirement = EvidenceRequirement.create!(origin: "manual", competency_item: competency_items(:sub_anamnesis),
      source_type: "external", required_count: 1, fulfillment_rule: { "require_validation" => true })
    @source = CanonicalEvidenceIngestor.new(source_system: "moodle", requirement: @requirement,
      payload: { "source_record_id" => "task-review", "source_revision" => "rev-1", "activity_key" => "task-review-1",
        "student" => @student, "occurred_on" => Date.current.iso8601, "result" => "pass",
        "metadata" => { "source_hash" => "abc", "jejak_imported_by_id" => @reviewer.id } }).call.evidence_source
  end

  test "assigned reviewer validates source and validation completes the requirement" do
    assign_reviewer
    sign_in @reviewer

    get evidence_sources_path
    assert_response :success
    assert_select "a", text: "Penilaian & Validasi Bukti Eksternal", count: 0
    assert_select "h1", text: "Penilaian & Validasi Bukti Eksternal"

    patch validate_evidence_source_path(@source)
    assert_redirected_to evidence_sources_path
    assert_equal "validated", @source.reload.validation_status
    assert_equal @reviewer, @source.validated_by
    assert_equal :fulfilled, EvidenceRequirementProgress.new(@requirement).call.status
  end

  test "reviewer cannot validate their own imported batch" do
    assign_reviewer
    @source.update_column(:metadata, @source.metadata.merge("jejak_imported_by_id" => @reviewer.id))
    sign_in @reviewer

    get evidence_sources_path
    assert_response :success
    assert_select "article", count: 0
    patch validate_evidence_source_path(@source)
    assert_equal "unverified", @source.reload.validation_status
  end

  test "admin without an explicit reviewer assignment cannot review external sources" do
    admin = users(:budi)
    grant_bootstrapped_system_admin!(admin)
    sign_in admin

    get evidence_sources_path
    assert_redirected_to root_path
    patch validate_evidence_source_path(@source)
    assert_equal "unverified", @source.reload.validation_status
  end

  test "rejection requires a reason and keeps source payload immutable" do
    assign_reviewer
    sign_in @reviewer

    patch reject_evidence_source_path(@source), params: { reason: "Tidak sesuai sumber" }
    assert_redirected_to evidence_sources_path
    assert_equal "rejected", @source.reload.validation_status
    assert_equal "Tidak sesuai sumber", @source.metadata["rejection_reason"]
    assert_raises(ActiveRecord::RecordInvalid) { @source.update!(feedback: "payload diubah") }
  end

  private

  def assign_reviewer
    UserAssignment.create!(user: @reviewer, assigned_by: @reviewer, study_program: @program,
      assignment_role: "evidence_reviewer", scope_type: "StudyProgram", scope_id: @program.id,
      reason: "Ditugaskan meninjau bukti eksternal program studi.")
  end
end
