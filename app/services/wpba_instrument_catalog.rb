# frozen_string_literal: true

class WpbaInstrumentCatalog
  BUILT_INS = {
    "mini_cex" => ["MINI-CEX", "Mini-CEX", MiniCexEvaluation::DIMENSIONS],
    "dops" => ["DOPS", "DOPS", DopsEvaluation::DIMENSIONS],
    "cbd" => ["CBD", "Case-Based Discussion", {}],
    "cec" => ["CEC", "Clinical Encounter Card", {}],
    "cws" => ["CWS", "Clinical Work Sampling", {}],
    "bpe" => ["BPE", "Blinded Patient Encounter", {}],
    "msf" => ["MSF", "Multisource Feedback", {}]
  }.freeze
  METHOD_COMPONENTS = {
    "mini_cex" => %w[history focused_examination clinical_reasoning communication professionalism organization],
    "cec" => %w[history focused_examination clinical_reasoning management communication overall],
    "cws" => %w[clinical_work prioritization safety teamwork reliability overall],
    "bpe" => %w[clinical_reasoning communication examination safety overall],
    "dops" => %w[preparation indication procedure asepsis safety aftercare overall],
    "cbd" => %w[case_presentation clinical_reasoning decisions evidence reflection],
    "msf" => %w[communication teamwork reliability professionalism respect]
  }.freeze
  COMPONENT_LABELS = {
    "history" => "Anamnesis terarah", "focused_examination" => "Pemeriksaan terarah",
    "clinical_reasoning" => "Penalaran klinis", "management" => "Rencana tata laksana",
    "communication" => "Komunikasi", "professionalism" => "Profesionalisme",
    "organization" => "Organisasi dan efisiensi", "clinical_work" => "Mutu pekerjaan klinis",
    "prioritization" => "Prioritas tugas", "safety" => "Keselamatan pasien",
    "teamwork" => "Kerja sama tim", "reliability" => "Keandalan dan tanggung jawab",
    "examination" => "Pemeriksaan klinis", "preparation" => "Persiapan prosedur",
    "indication" => "Indikasi dan persetujuan", "procedure" => "Pelaksanaan prosedur",
    "asepsis" => "Asepsis", "aftercare" => "Perawatan setelah prosedur",
    "case_presentation" => "Presentasi kasus", "decisions" => "Keputusan klinis",
    "evidence" => "Penggunaan bukti ilmiah", "reflection" => "Refleksi dan pembelajaran",
    "respect" => "Sikap saling menghormati", "overall" => "Penilaian keseluruhan"
  }.freeze

  def self.ensure_defaults!
    BUILT_INS.each do |type, (code, name, dimensions)|
      instrument = WpbaInstrument.find_or_create_by!(code: code) do |record|
        record.name = name
        record.instrument_type = type
      end
      instrument.versions.find_or_create_by!(version_label: "1.0") do |version|
        version.definition = {
          "dimensions" => dimensions,
          "components" => components_for(type),
          "method" => type,
          "assessor_blinded" => type == "bpe",
          "minimum_raters" => (3 if type == "msf"),
          "capture_context" => true,
          "capture_narrative_feedback" => true,
          "source" => "JEJAK built-in",
          "version_note" => "Definisi awal untuk kompatibilitas dengan instrumen yang sudah tersedia."
        }
        version.published_at = Time.current
      end
    end
    # Retain legacy records, but never offer EPA observations as WPBA forms.
    WpbaInstrument.where(code: "EPA-OBS").update_all(active: false)
  end

  def self.version_for(type)
    ensure_defaults!
    WpbaInstrument.find_by!(instrument_type: type).current_version
  end

  def self.components_for(type)
    Array(METHOD_COMPONENTS[type]).map do |key|
      {
        "key" => key, "label" => COMPONENT_LABELS.fetch(key, key.humanize),
        "type" => "rating", "minimum" => 1, "maximum" => 4, "required" => true,
        "levels" => {
          "1" => { "label" => "Perlu bimbingan", "description" => "Belum konsisten; memerlukan arahan langsung." },
          "2" => { "label" => "Berkembang", "description" => "Sebagian langkah tepat dengan supervisi langsung." },
          "3" => { "label" => "Kompeten", "description" => "Memenuhi standar pada konteks dan kompleksitas yang diamati." },
          "4" => { "label" => "Unggul", "description" => "Kinerja konsisten dan dapat menjelaskan pertimbangannya." }
        }
      }
    end
  end
end
