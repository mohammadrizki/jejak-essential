# frozen_string_literal: true

# Creates a complete, isolated CanMEDS-derived curriculum example for the
# opt-in demo dataset. The sample is an institutional illustration, not an
# official CanMEDS indicator set or an alteration to the standard programs.
class CanmedsCurriculumShowcaseSeeder
  PROGRAM_CODE = "demo-canmeds-sarjana"
  FRAMEWORK_NAME = "CONTOH — Adaptasi CanMEDS Sarjana"
  BLUEPRINT_NAME = "CONTOH — Blueprint Asesmen CanMEDS Sarjana"

  EPA_DEFINITIONS = [
    {
      code: "EPA-SAR-01",
      title: "Mengumpulkan dan menyajikan informasi klinis dasar",
      description: "Menggali informasi yang relevan, menjaga privasi, dan menyampaikan ringkasan kasus dalam kegiatan belajar yang disupervisi.",
      scope: "Wawancara dan presentasi kasus pada simulasi atau kegiatan klinik yang diizinkan program.",
      limitations: "Mahasiswa tidak menetapkan diagnosis final atau melakukan tindakan tanpa izin dan supervisi langsung.",
      mappings: [
        [ "ME-KLIN-01", "skill", "important", false, false ],
        [ "COM-INFORM-01", "skill", "important", false, false ],
        [ "PROF-ETIK-02", "attitude", "critical", true, true ]
      ]
    },
    {
      code: "EPA-SAR-02",
      title: "Mengusulkan langkah awal yang aman dalam diskusi kasus",
      description: "Menggunakan penalaran dasar untuk mengusulkan pemeriksaan atau langkah awal dan mengenali kapan harus meminta bantuan.",
      scope: "Diskusi kasus dan simulasi klinis dengan keputusan akhir berada pada pembimbing.",
      limitations: "Usulan bukan instruksi terapi mandiri; tindakan hanya dilakukan setelah persetujuan pembimbing.",
      mappings: [
        [ "ME-NALAR-02", "knowledge", "important", false, false ],
        [ "ME-RENCANA-01", "knowledge", "important", false, false ],
        [ "PROF-BATAS-01", "attitude", "critical", true, true ]
      ]
    },
    {
      code: "EPA-SAR-03",
      title: "Memberikan edukasi kesehatan dasar pada simulasi",
      description: "Menjelaskan informasi kesehatan sederhana dan memeriksa pemahaman pasien dalam latihan komunikasi.",
      scope: "Edukasi preventif atau penjelasan rencana pada pasien simulasi atau kegiatan terawasi.",
      limitations: "Informasi harus sesuai bahan yang disetujui; konsultasikan pertanyaan klinis di luar kompetensi kepada pembimbing.",
      mappings: [
        [ "COM-EDUK-01", "skill", "important", false, false ],
        [ "HA-PROMO-02", "knowledge", "supporting", false, false ],
        [ "PROF-ETIK-01", "attitude", "critical", true, true ]
      ]
    }
  ].freeze

  BLUEPRINT_COMPONENTS = [
    {
      code: "CONTOH-MCEX-01", method: "mini_cex", title: "Wawancara dan komunikasi klinis",
      context: "Dua observasi terpisah; pembimbing memberi umpan balik segera. Contoh ini menunjukkan rancangan, bukan aturan universal.",
      weight: 30, target_count: 2, indicator_codes: %w[ME-KLIN-01 COM-HUB-02 COM-INFORM-01 COL-KOM-01], epa_code: "EPA-SAR-01"
    },
    {
      code: "CONTOH-OSCE-01", method: "osce", title: "OSCE keselamatan dan prosedur dasar",
      context: "Station simulasi dengan daftar tilik keselamatan dan standar kinerja indikator.",
      weight: 30, target_count: 1, indicator_codes: %w[ME-AMAN-02 PROF-ETIK-01 HA-PROMO-02], epa_code: "EPA-SAR-02"
    },
    {
      code: "CONTOH-CBD-01", method: "cbd", title: "Diskusi penalaran kasus dan bukti ilmiah",
      context: "Diskusi kasus untuk menilai alasan klinis, ketidakpastian, serta penggunaan sumber ilmiah.",
      weight: 25, target_count: 2, indicator_codes: %w[ME-NALAR-02 SCH-BUKTI-02 LEAD-MUTU-01], epa_code: "EPA-SAR-02"
    },
    {
      code: "CONTOH-REFLEKSI-01", method: "reflection", title: "Refleksi dan rencana perbaikan",
      context: "Refleksi terpilih ditelaah bersama pembimbing dan dihubungkan dengan umpan balik.",
      weight: 15, target_count: 1, indicator_codes: %w[SCH-REF-01 SCH-REF-02 PROF-SEHAT-02 COL-KONFLIK-02], epa_code: "EPA-SAR-03"
    }
  ].freeze

  BLUEPRINT_EVIDENCE_RULES = [
    {
      item_code: "CONTOH-MCEX-01", indicator_code: "ME-KLIN-01", source_type: "wpba",
      required_count: 2, minimum_pass: 1, minimum_distinct_assessors: 2,
      minimum_distinct_opportunities: 2, critical: false,
      additional_criteria: "Observasi berasal dari kesempatan klinis berbeda dan disertai umpan balik spesifik."
    },
    {
      item_code: "CONTOH-OSCE-01", indicator_code: "ME-AMAN-02", source_type: "assessment",
      required_count: 1, minimum_pass: 1, critical: true,
      additional_criteria: "Langkah keselamatan dan pencegahan infeksi yang kritis harus terpenuhi."
    },
    {
      item_code: "CONTOH-CBD-01", indicator_code: "ME-NALAR-02", source_type: "wpba",
      required_count: 2, minimum_pass: 1, minimum_distinct_cases: 2,
      minimum_distinct_assessors: 2, critical: false,
      additional_criteria: "Diskusi membahas alasan klinis, ketidakpastian, dan batas pengetahuan mahasiswa."
    },
    {
      item_code: "CONTOH-REFLEKSI-01", indicator_code: "SCH-REF-01", source_type: "reflection",
      required_count: 1, minimum_valid_evidence: 1, critical: false,
      additional_criteria: "Refleksi menyebutkan pengalaman, pembelajaran, area perbaikan, dan tindak lanjut."
    }
  ].freeze

  def self.call = new.call

  def call
    program = StudyProgram.find_or_create_by!(code: PROGRAM_CODE) do |record|
      record.name = "Program Contoh — Adaptasi CanMEDS Sarjana"
      record.level = "sarjana"
    end

    framework = program.framework_versions.find_by(name: FRAMEWORK_NAME)
    existing_blueprint = program.assessment_blueprint
    return framework if framework&.published? && existing_blueprint&.name == BLUEPRINT_NAME &&
      existing_blueprint.current_version&.competency_framework_id == framework.id &&
      existing_blueprint.current_version&.status == "published" && blueprint_has_example_evidence?(existing_blueprint.current_version)

    CompetencyFramework.transaction do
      framework ||= duplicate_framework(program)
      build_epas(framework) if framework.status == "draft" && framework.epas.empty?
      framework.publish! if framework.status == "draft"
      blueprint = build_blueprint(program, framework)
      ensure_blueprint_evidence_requirements!(blueprint, framework)
      framework
    end
  end

  private

  def duplicate_framework(program)
    template = CompetencyFrameworkTemplate.find_by_key("canmeds_undergraduate_v1")
    raise ActiveRecord::RecordNotFound, "Template CanMEDS bawaan tidak ditemukan" unless template

    CompetencyFrameworkDuplicator.new(
      study_program: program,
      name: FRAMEWORK_NAME,
      template: template
    ).call
  end

  def build_epas(framework)
    EPA_DEFINITIONS.each do |definition|
      epa = framework.epas.create!(
        code: definition.fetch(:code), title: definition.fetch(:title),
        description: definition.fetch(:description), scope: definition.fetch(:scope),
        limitations: definition.fetch(:limitations), status: "draft"
      )

      definition.fetch(:mappings).each do |indicator_code, ksa, contribution, prerequisite, critical|
        indicator = framework.competency_indicators.find_by!(code: indicator_code)
        epa.epa_competencies.create!(
          competency_item: indicator.competency_item,
          competency_indicator: indicator,
          ksa_dimension: ksa,
          contribution: contribution,
          is_prerequisite: prerequisite,
          minimum_attainment_level: prerequisite ? 2 : nil,
          is_critical: critical,
          notes: "Contoh pemetaan lokal; program studi menetapkan standar dan kewenangan akhirnya."
        )
      end
    end
  end

  def build_blueprint(program, framework)
    blueprint = program.assessment_blueprint
    if blueprint && blueprint.name != BLUEPRINT_NAME
      blueprint.errors.add(:base, "Program contoh sudah memiliki Blueprint Asesmen lain; data itu tidak diubah oleh seeder.")
      raise ActiveRecord::RecordInvalid.new(blueprint)
    end
    if blueprint.nil?
      blueprint = AssessmentBlueprint.new(
        study_program: program,
        name: BLUEPRINT_NAME,
        description: "Contoh blueprint hybrid: metode internal dan WPBA yang dipetakan ke indikator serta EPA. Bobot dan jumlah hanya ilustrasi untuk disesuaikan institusi.",
        learning_outcomes: [
          "Mengumpulkan dan menyajikan informasi klinis dasar secara aman.",
          "Menggunakan penalaran dasar untuk mengusulkan langkah awal dengan supervisi.",
          "Berkomunikasi dan merefleksikan perkembangan secara profesional."
        ]
      )
      blueprint.initial_competency_framework_id = framework.id
      blueprint.save!
    end

    version = blueprint.draft_version
    if version.blank?
      source_version = blueprint.current_version
      version = blueprint.blueprint_versions.create!(
        competency_framework: framework,
        version: (blueprint.blueprint_versions.maximum(:version) || 0) + 1,
        status: "draft",
        change_notes: "Versi contoh untuk melengkapi Bukti yang Diharapkan dan Peta Artefak."
      )
      copy_blueprint_items!(source_version, version) if source_version
    end
    raise ActiveRecord::RecordInvalid.new(version) if version.competency_framework_id != framework.id

    BLUEPRINT_COMPONENTS.each do |definition|
      item = version.blueprint_items.find_or_create_by!(code: definition.fetch(:code)) do |record|
        record.assessment_method = AssessmentMethod.find_by!(code: definition.fetch(:method))
        record.title = definition.fetch(:title)
        record.assessment_context = definition.fetch(:context)
        record.weight = definition.fetch(:weight)
        record.target_count = definition.fetch(:target_count)
        record.position = BLUEPRINT_COMPONENTS.index(definition) + 1
      end

      definition.fetch(:indicator_codes).each do |indicator_code|
        indicator = framework.competency_indicators.find_by!(code: indicator_code)
        item.blueprint_item_competencies.find_or_create_by!(
          competency_item: indicator.competency_item,
          competency_indicator: indicator
        ) do |mapping|
          mapping.notes = "Contoh hubungan komponen asesmen dengan indikator Peta Kompetensi."
        end
      end

      epa = framework.epas.find_by!(code: definition.fetch(:epa_code))
      item.blueprint_item_epas.find_or_create_by!(epa: epa, assessment_purpose: "formative")
      item
    end

    summary_weights = { "ME" => 35, "COM" => 15, "COL" => 10, "LEAD" => 10, "HA" => 10, "SCH" => 10, "PROF" => 10 }
    summary_weights.each do |domain_code, weight|
      domain = framework.competency_items.find_by!(code: domain_code)
      blueprint.assessment_blueprint_mappings.find_or_create_by!(competency_item: domain) do |mapping|
        mapping.weight = weight
      end
    end

    blueprint
  end

  def ensure_blueprint_evidence_requirements!(blueprint, framework)
    version = blueprint.draft_version
    raise ActiveRecord::RecordInvalid.new(blueprint) if version.blank?

    BLUEPRINT_EVIDENCE_RULES.each do |definition|
      item = version.blueprint_items.find_by!(code: definition.fetch(:item_code))
      indicator = framework.competency_indicators.find_by!(code: definition.fetch(:indicator_code))
      next if item.evidence_requirements.exists?(competency_indicator_id: indicator.id, status: "active")

      fulfillment_rule = {
        require_validation: true,
        valid_results: %w[pass borderline],
        minimum_valid_evidence: definition.fetch(:required_count),
        minimum_pass: definition.fetch(:minimum_pass, 0),
        minimum_distinct_cases: definition.fetch(:minimum_distinct_cases, 0),
        minimum_distinct_assessors: definition.fetch(:minimum_distinct_assessors, 0),
        minimum_distinct_opportunities: definition.fetch(:minimum_distinct_opportunities, 0),
        critical: definition.fetch(:critical),
        additional_criteria: definition.fetch(:additional_criteria)
      }
      item.evidence_requirements.create!(
        origin: "blueprint", source_type: definition.fetch(:source_type),
        required_count: definition.fetch(:required_count), status: "active",
        is_mandatory: true, due_stage: "sarjana", assessment_method: item.assessment_method,
        competency_item: indicator.competency_item, competency_indicator: indicator,
        fulfillment_rule: fulfillment_rule
      )
    end

    version.publish! if version.status == "draft"
  end

  def copy_blueprint_items!(source_version, target_version)
    source_version.blueprint_items.includes(
      blueprint_item_competencies: %i[competency_item competency_indicator],
      blueprint_item_epas: %i[epa supervision_level], evidence_requirements: :versions
    ).each do |source_item|
      item = target_version.blueprint_items.create!(
        source_item.attributes.except("id", "blueprint_version_id", "created_at", "updated_at")
      )
      source_item.blueprint_item_competencies.each do |mapping|
        item.blueprint_item_competencies.create!(
          mapping.attributes.except("id", "blueprint_item_id", "created_at", "updated_at")
        )
      end
      source_item.blueprint_item_epas.each do |mapping|
        item.blueprint_item_epas.create!(
          mapping.attributes.except("id", "blueprint_item_id", "created_at", "updated_at")
        )
      end
      source_item.evidence_requirements.each do |requirement|
        next if requirement.status != "active"

        item.evidence_requirements.create!(
          requirement.attributes.except("id", "blueprint_item_id", "created_at", "updated_at")
        )
      end
    end
  end

  def blueprint_has_example_evidence?(version)
    BLUEPRINT_EVIDENCE_RULES.all? do |definition|
      item = version.blueprint_items.find_by(code: definition.fetch(:item_code))
      indicator = version.competency_framework.competency_indicators.find_by(code: definition.fetch(:indicator_code))
      item && indicator && item.evidence_requirements.exists?(competency_indicator_id: indicator.id, status: "active")
    end
  end
end
