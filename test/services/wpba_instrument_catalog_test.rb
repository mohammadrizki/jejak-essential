require "test_helper"

class WpbaInstrumentCatalogTest < ActiveSupport::TestCase
  test "built-in catalog contains seven WPBA methods but not EPA observations" do
    WpbaInstrumentCatalog.ensure_defaults!

    instruments = WpbaInstrument.includes(:versions).active.index_by(&:instrument_type)
    assert_equal %w[bpe cbd cec cws dops mini_cex msf], instruments.keys.sort
    assert instruments.values.all? { |instrument| instrument.current_version.present? }
    assert_equal "Case-Based Discussion", instruments.fetch("cbd").name
    assert_not WpbaInstrument.exists?(code: "EPA-OBS", active: true)
    assert WpbaInstrument::WPBA_TYPES.all? { |type| instruments.fetch(type).current_version.components.any? }
  end

  test "a published version cannot be edited" do
    WpbaInstrumentCatalog.ensure_defaults!
    instrument = WpbaInstrument.find_by!(instrument_type: "mini_cex")
    version = instrument.versions.create!(version_label: "test-unpublished", definition: { "items" => [] })
    version.publish!(by: users(:budi))
    version.definition = { "changed" => true }

    assert_raises(ActiveRecord::RecordInvalid) { version.save! }
  end

  test "instrumen khusus mendukung jangkar deskriptif untuk setiap level rating" do
    instrument = WpbaInstrument.create!(code: "RUBRIC-#{SecureRandom.hex(3)}", name: "Rubrik klinis", instrument_type: "other")
    version = instrument.versions.create!(version_label: "1.0", definition: { components: [
      { key: "communication", label: "Komunikasi", type: "rating", minimum: 1, maximum: 3, required: true,
        levels: { "1" => { label: "Perlu bimbingan", description: "Belum terstruktur." },
                  "2" => { label: "Cukup", description: "Terstruktur dengan arahan." },
                  "3" => { label: "Mandiri", description: "Terstruktur dan empatik." } }
      }
    ] })

    assert_equal "Cukup", version.component_response_label(version.components.first, 2)
    assert_equal "Terstruktur dengan arahan.", version.component_response_description(version.components.first, 2)

    invalid_version = instrument.versions.build(version_label: "2.0", definition: { components: [
      { key: "communication", label: "Komunikasi", type: "rating", minimum: 1, maximum: 3,
        levels: { "1" => "Perlu bimbingan", "3" => "Mandiri" } }
    ] })
    assert_not invalid_version.valid?
    assert_includes invalid_version.errors[:definition].join, "setiap nilai 1–3"
  end
end
