require "test_helper"

class EvidenceRecordDatabaseConstraintTest < ActiveSupport::TestCase
  test "source constraint covers every local evidence source including WPBA observations" do
    expression = EvidenceRecord.connection.check_constraints(:evidence_records)
      .find { |constraint| constraint.name == "chk_evidence_record_single_source" }&.expression

    assert expression, "expected the database to define chk_evidence_record_single_source"
    %w[assessment_instance_id activity_log_id reflection_entry_id epa_observation_id
       mini_cex_evaluation_id dops_evaluation_id wpba_observation_id].each do |column|
      assert_includes expression, column
    end
  end

  test "database accepts a WPBA observation as the sole local source" do
    requirement = EvidenceRequirement.create!(origin: "manual", competency_item: competency_items(:sub_anamnesis),
      source_type: "wpba", required_count: 1)
    observation = build_wpba_observation
    canonical_source = EvidenceSource.for_local_record!(observation)

    assert_difference "EvidenceRecord.count", 1 do
      insert_record!(requirement, wpba_observation_id: observation.id, evidence_source_id: canonical_source.id)
    end
  end

  test "database accepts a canonical evidence source without a local source foreign key" do
    requirement = EvidenceRequirement.create!(origin: "manual", competency_item: competency_items(:sub_anamnesis),
      source_type: "external", required_count: 1)
    source = EvidenceSource.create!(student: users(:siti), source_system: "external-test",
      source_type: "external", source_record_id: SecureRandom.uuid, source_revision: "1",
      activity_key: "external-test:#{SecureRandom.uuid}", occurred_on: Date.current)

    assert_difference "EvidenceRecord.count", 1 do
      insert_record!(requirement, evidence_source_id: source.id)
    end
  end

  test "database rejects a record with no evidence source" do
    requirement = EvidenceRequirement.create!(origin: "manual", competency_item: competency_items(:sub_anamnesis),
      source_type: "wpba", required_count: 1)

    assert_database_check_rejects do
      insert_record!(requirement)
    end
  end

  test "database rejects records that point to multiple local sources" do
    requirement = EvidenceRequirement.create!(origin: "manual", competency_item: competency_items(:sub_anamnesis),
      source_type: "wpba", required_count: 1)
    observation = build_wpba_observation
    logbook = activity_logs(:jaga_igd)
    canonical_source = EvidenceSource.for_local_record!(observation)

    assert_database_check_rejects do
      insert_record!(requirement, wpba_observation_id: observation.id, activity_log_id: logbook.id,
        evidence_source_id: canonical_source.id)
    end
  end

  test "database rejects linking one EPA observation twice to the same requirement" do
    requirement = epa_requirement
    observation = epa_observation(requirement.epa)
    insert_record!(requirement, epa_observation_id: observation.id)

    error = assert_raises(ActiveRecord::RecordNotUnique) do
      EvidenceRecord.transaction(requires_new: true) do
        insert_record!(requirement, epa_observation_id: observation.id)
      end
    end

    assert_match(/idx_evidence_record_epa_observation_once/, error.message)
  end

  private

  def build_wpba_observation
    instrument = WpbaInstrument.create!(code: "DB-CHECK-#{SecureRandom.hex(4)}", name: "Uji constraint DB",
      instrument_type: "other")
    version = instrument.versions.create!(version_label: "1.0", definition: { "components" => [
      { "key" => "performance", "label" => "Kinerja", "type" => "text", "required" => false }
    ] })
    version.publish!(by: users(:budi))
    now = Time.current
    WpbaObservation.insert!({
      student_id: users(:siti).id,
      observer_id: users(:budi).id,
      clinical_rotation_id: clinical_rotations(:ongoing_rotation_siti).id,
      wpba_instrument_version_id: version.id,
      observed_at: now,
      status: "draft",
      activity_summary: "Observasi untuk uji constraint",
      clinical_context: {},
      responses: {},
      created_at: now,
      updated_at: now
    })
    WpbaObservation.order(:id).last
  end

  def epa_requirement
    framework = competency_frameworks(:skdi_ringkas)
    epa = framework.epas.create!(code: "DB-UNIQUE-#{SecureRandom.hex(3)}", title: "EPA untuk tes constraint")
    EvidenceRequirement.create!(epa: epa, origin: "manual", source_type: "epa_observation", required_count: 1)
  end

  def epa_observation(epa)
    scale = SupervisionScaleVersion.create!(code: "db_unique_#{SecureRandom.hex(3)}", name: "Skala uji DB",
      version_label: "1", use_case: "retrospective_observation")
    level = scale.supervision_levels.create!(ordinal: 1, code: "observed", label: "Diamati",
      description: "Supervisor mengamati langsung.")
    now = Time.current
    EpaObservation.insert!({
      student_id: users(:siti).id,
      epa_id: epa.id,
      observer_id: users(:budi).id,
      supervision_level_id: level.id,
      observed_at: now,
      complexity: "routine",
      narrative: "Observasi untuk pengujian indeks unik.",
      safety_flag: false,
      status: "recorded",
      created_at: now,
      updated_at: now
    })
    EpaObservation.order(:id).last
  end

  def insert_record!(requirement, source_attributes = {})
    EvidenceRecord.insert!({
      evidence_requirement_id: requirement.id,
      evidence_requirement_version_id: requirement.current_version.id,
      evidence_date: Date.current,
      result: "other",
      metadata: {},
      created_at: Time.current,
      updated_at: Time.current
    }.merge(source_attributes))
  end

  def assert_database_check_rejects(&block)
    error = assert_raises(ActiveRecord::StatementInvalid) do
      EvidenceRecord.transaction(requires_new: true, &block)
    end

    assert_match(/chk_evidence_record_single_source/, error.message)
  end
end
