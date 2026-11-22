require "test_helper"

class WpbaObservationTest < ActiveSupport::TestCase
  setup do
    @instrument = WpbaInstrument.create!(code: "CUSTOM-#{SecureRandom.hex(3)}", name: "Konsultasi teramati", instrument_type: "other")
    @version = @instrument.versions.create!(version_label: "1.0", definition: {
      "components" => [
        { "key" => "performance", "label" => "Kinerja", "type" => "rating", "minimum" => 1, "maximum" => 5, "required" => true },
        { "key" => "safe", "label" => "Aman", "type" => "boolean", "required" => true }
      ]
    })
    @version.publish!(by: users(:budi))
  end

  test "mengizinkan instrumen fleksibel yang valid dan menolak komponen tak dikenal saat dikirim" do
    observation = build_observation(responses: { "performance" => 4, "safe" => false })
    assert observation.valid?, observation.errors.full_messages.to_sentence

    observation.responses["invented"] = "x"
    assert_not observation.valid?
    assert_includes observation.errors[:responses].join, "tidak didefinisikan"
  end

  test "tidak dapat menggunakan versi instrumen khusus yang belum diterbitkan" do
    @version.update_column(:published_at, nil)
    observation = build_observation
    assert_not observation.valid?
    assert observation.errors[:wpba_instrument_version].any?
  end

  test "observasi terkirim menjadi bukti kanonis dan koreksi tidak menambah kesempatan independen" do
    requirement = EvidenceRequirement.create!(origin: "manual", competency_item: competency_items(:sub_anamnesis),
      source_type: "wpba", required_count: 1)
    original = build_observation
    original.save!
    source = EvidenceSource.for_local_record!(original)
    record = EvidenceRecord.create!(evidence_requirement: requirement, wpba_observation: original,
      evidence_source: source, evidence_date: Date.current, result: "other")

    correction = original.dup
    correction.assign_attributes(status: "draft", submitted_at: nil, observer: users(:budi),
      corrects: original, correction_reason: "Nilai perlu dikoreksi sesuai catatan observasi asli.")
    correction.save!
    correction.responses = { "performance" => 5, "safe" => true }
    correction.submit!

    replacement = requirement.evidence_records.find_by!(wpba_observation: correction)
    progress = EvidenceRequirementProgress.new(requirement, student: users(:siti)).call
    assert_equal source.activity_key, replacement.evidence_source.activity_key
    assert_equal 1, progress.opportunity_count
    assert_equal [replacement.id], progress.eligible_record_ids
  end

  private

  def build_observation(responses: { "performance" => 4, "safe" => true })
    WpbaObservation.new(student: users(:siti), observer: users(:budi),
      clinical_rotation: clinical_rotations(:ongoing_rotation_siti), wpba_instrument_version: @version,
      observed_at: Time.current, activity_summary: "Melakukan konsultasi terstruktur", status: "submitted",
      submitted_at: Time.current, clinical_context: { complexity: "Sedang" }, responses: responses)
  end
end
