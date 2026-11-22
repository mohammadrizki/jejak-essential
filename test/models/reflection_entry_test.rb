require "test_helper"

class ReflectionEntryTest < ActiveSupport::TestCase
  test "structured prompts are saved as a backwards-compatible content snapshot" do
    reflection = ReflectionEntry.create!(user: users(:siti), entry_date: Date.current,
      what_happened: "Saya menerima umpan balik tentang komunikasi.",
      what_learned: "Saya perlu merangkum pemahaman pasien.",
      what_to_improve: "Latihan mendengar aktif.",
      next_action: "Meminta umpan balik pada sesi berikutnya.")

    assert_includes reflection.content, "Apa yang saya alami?"
    assert_includes reflection.content, "Meminta umpan balik pada sesi berikutnya."
  end

  test "reflection competencies must belong to the learner's program framework" do
    other_framework = CompetencyFramework.create!(study_program: study_programs(:profesi_dokter),
      name: "Kerangka program lain", version: "ref-test", education_stage: "profesi")
    other_item = other_framework.competency_items.create!(title: "Kompetensi lain", code: "RF-1", level_type: "domain")
    reflection = ReflectionEntry.new(user: users(:siti), entry_date: Date.current,
      what_learned: "Saya memperoleh pelajaran.", competency_items: [other_item])

    assert_not reflection.valid?
    assert reflection.errors[:competency_items].any?
  end

  test "reflection can only link evidence owned by its author" do
    source = EvidenceSource.create!(student: users(:siti), source_system: "jejak", source_type: "wpba",
      source_record_id: "reflection-test-#{SecureRandom.hex(4)}", source_revision: "1", activity_key: "wpba:reflection-test",
      occurred_on: Date.current, validation_status: "unverified")
    reflection = ReflectionEntry.new(user: users(:dedi), entry_date: Date.current,
      what_learned: "Saya memahami batas keputusan.", evidence_sources: [source])

    assert_not reflection.valid?
    assert reflection.errors[:evidence_sources].any?
  end
end
