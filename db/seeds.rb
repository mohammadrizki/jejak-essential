# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

{
  "mahasiswa" => "Mahasiswa",
  "dosen"     => "Dosen",
  "preseptor" => "Preseptor",
  "kaprodi"   => "Kaprodi",
  "admin"     => "Admin",
  "tenaga_kependidikan" => "Tenaga Kependidikan",
  "superadmin" => "Superadmin"
}.each do |code, name|
  Role.find_or_create_by!(code: code) { |role| role.name = name }
end

# Hak akses peran menentukan tindakan; UserAssignment tetap menjadi
# syarat kedua untuk membatasi mahasiswa, rotasi, dan dossier yang ditangani.
{
  "admin" => %w[users.manage roles.assign assignments.manage curriculum.manage modules.manage integration.manage audit.read],
  "kaprodi" => %w[users.manage roles.assign assignments.manage curriculum.manage modules.manage assessment.review assessment.decide epa.decide audit.read],
  "dosen" => %w[assessment.review assessment.decide],
  "preseptor" => %w[assessment.review epa.decide],
  "tenaga_kependidikan" => %w[integration.manage audit.read]
}.each do |role_code, permission_keys|
  role = Role.find_by!(code: role_code)
  permission_keys.each do |key|
    permission = SystemPermission.find_by!(key: key)
    RolePermission.find_or_create_by!(role: role, system_permission: permission) do |grant|
      grant.scope_level = "system"
    end
  end
end

superadmin = Role.find_by!(code: "superadmin")
%w[users.manage roles.manage roles.assign assignments.manage curriculum.manage modules.manage integration.manage audit.read templates.manage].each do |key|
  permission = SystemPermission.find_by!(key: key)
  RolePermission.find_or_create_by!(role: superadmin, system_permission: permission) do |grant|
    grant.scope_level = "system"
  end
end

# Prodi contoh awal. Prodi Spesialis dan Subspesialis serta prodi tambahan
# dibuat melalui Konfigurasi → Program Studi; seed tidak menghapus master data.
{ "Sarjana Kedokteran" => %w[pssk sarjana], "Profesi Dokter" => %w[pspd profesi] }.each do |name, (code, level)|
  sp = StudyProgram.find_or_initialize_by(name: name)
  sp.code  ||= code
  sp.level ||= level
  sp.save!
end

[
  ["cbt", "Computer-based test", "written"], ["osce", "OSCE", "practical"],
  ["mini_cex", "Mini-CEX", "workplace"], ["dops", "DOPS", "workplace"],
  ["cbd", "Case-based discussion", "case"], ["portfolio", "Portfolio review", "portfolio"],
  ["reflection", "Refleksi", "reflection"]
].each do |code, name, type|
  AssessmentMethod.find_or_create_by!(code: code) do |method|
    method.name = name
    method.assessment_type = type
  end
end

# Taksonomi Logbook Kegiatan (Domain → Subdomain → Bentuk Kegiatan). Hanya
# mengisi basis data yang belum punya domain sama sekali —
# domain yang dihapus admin tidak muncul lagi di deploy berikutnya.
AcademicActivityTaxonomySeeder.call

# Fase 10 — Formulir Evaluasi baku: tutor evaluation, evaluasi blok,
# asesmen tambahan. Dibangun di atas Form Builder (Fase 9), bukan model
# terpisah — templat ini contoh siap pakai, admin bebas menambah/mengubah.
{
  "Evaluasi Dosen Tutor" => {
    description: "Penilaian mahasiswa terhadap dosen pembimbing kelompok tutorial.",
    anonymous: true,
    requires_subject_user: true,
    fields: [
      { label: "Dosen tutor hadir tepat waktu", field_type: "rating" },
      { label: "Dosen tutor mendorong diskusi aktif", field_type: "rating" },
      { label: "Dosen tutor memberi umpan balik yang membangun", field_type: "rating" },
      { label: "Saran perbaikan untuk dosen tutor", field_type: "textarea", required: false }
    ]
  },
  "Evaluasi Blok" => {
    description: "Penilaian mahasiswa terhadap penyelenggaraan satu blok pembelajaran.",
    anonymous: true,
    requires_subject_user: false,
    fields: [
      { label: "Tujuan pembelajaran blok tersampaikan dengan jelas", field_type: "rating" },
      { label: "Beban tugas blok ini sesuai", field_type: "rating" },
      { label: "Apakah blok ini perlu direvisi materinya?", field_type: "yes_no" },
      { label: "Masukan untuk blok ini", field_type: "textarea", required: false }
    ]
  },
  "Asesmen Tambahan" => {
    description: "Formulir umum untuk kebutuhan asesmen di luar DOPS/Mini-CEX/Progress Test.",
    anonymous: false,
    requires_subject_user: false,
    fields: [
      { label: "Nama asesmen/kegiatan", field_type: "text" },
      { label: "Catatan penilai", field_type: "textarea", required: false }
    ]
  }
}.each do |name, attrs|
  template = AssessmentFormTemplate.find_or_create_by!(name: name) do |t|
    t.description = attrs[:description]
    t.anonymous = attrs[:anonymous]
    t.requires_subject_user = attrs[:requires_subject_user]
    t.is_active = true
  end

  next if template.assessment_form_fields.any?

  attrs[:fields].each do |field_attrs|
    template.assessment_form_fields.create!(
      label: field_attrs[:label],
      field_type: field_attrs[:field_type],
      required: field_attrs.fetch(:required, true)
    )
  end
end

# Kurikulum — satu Peta Kompetensi dan satu blueprint untuk masing-masing
# program studi. Blueprint dipetakan ke simpul peta milik prodi yang sama.
sarjana = StudyProgram.find_by!(code: "pssk")
profesi = StudyProgram.find_by!(code: "pspd")
framework = CompetencyFramework.find_or_create_by!(name: "Standar Kompetensi Dokter Indonesia (Ringkas)") do |f|
  f.description = "Tujuh area kompetensi inti dokter layanan primer."
  f.study_program = sarjana
end
framework.update!(study_program: sarjana) if framework.study_program_id.nil?

if framework.domains.none?
  {
    "Profesionalitas yang Luhur" => %w[Etika Disiplin],
    "Mawas Diri & Pengembangan Diri" => [ "Refleksi Praktik", "Belajar Sepanjang Hayat" ],
    "Komunikasi Efektif" => [ "Komunikasi Pasien", "Komunikasi Sejawat" ],
    "Pengelolaan Informasi" => [ "Rekam Medis", "Telaah Kritis" ],
    "Landasan Ilmiah Kedokteran" => [],
    "Keterampilan Klinis" => [ "Anamnesis & Pemeriksaan Fisik", "Prosedur Klinis Dasar" ],
    "Pengelolaan Masalah Kesehatan" => [ "Diagnosis", "Tata Laksana" ]
  }.each do |domain_name, sub_names|
    domain = framework.competency_items.create!(title: domain_name)
    sub_names.each { |sub_name| framework.competency_items.create!(title: sub_name, parent: domain) }
  end
end
framework.publish! if framework.status == "draft"

profession_framework = CompetencyFramework.find_or_initialize_by(study_program: profesi)
if profession_framework.new_record?
  profession_framework.name = "Standar Kompetensi Dokter Indonesia (Ringkas) — Profesi"
  profession_framework.description = framework.description
  profession_framework.save!
  framework.domains.includes(:children).each do |domain|
    copied_domain = profession_framework.competency_items.create!(title: domain.title, description: domain.description)
    domain.children.each do |child|
      profession_framework.competency_items.create!(title: child.title, description: child.description, parent: copied_domain)
    end
  end
end
profession_framework.publish! if profession_framework.status == "draft"

osce_blueprint = AssessmentBlueprint.find_by(study_program: profesi)
if osce_blueprint.nil?
  osce_blueprint = AssessmentBlueprint.create!(
    study_program: profesi,
    name: "Blueprint OSCE Komprehensif",
    description: "Distribusi bobot stasiun OSCE akhir tahap profesi.",
    learning_outcomes: [
      "Mampu melakukan anamnesis & pemeriksaan fisik sistematis",
      "Mampu menegakkan diagnosis banding yang rasional",
      "Mampu berkomunikasi secara empatik dengan pasien simulasi",
      "Menunjukkan perilaku profesional selama ujian"
    ]
  )
end

# Lengkapi hanya blueprint contoh buatan seed. Jangan menyisipkan contoh OSCE
# ke blueprint kustom yang sudah dimiliki program studi.
if osce_blueprint.name == "Blueprint OSCE Komprehensif"
  blueprint_framework = osce_blueprint.study_program.peta_kompetensi
  if osce_blueprint.assessment_blueprint_mappings.none? && blueprint_framework
    {
      "Keterampilan Klinis" => 35,
      "Komunikasi Efektif" => 20,
      "Pengelolaan Masalah Kesehatan" => 30,
      "Profesionalitas yang Luhur" => 15
    }.each do |domain_name, weight|
      item = blueprint_framework.competency_items.find_by(title: domain_name, parent_id: nil)
      osce_blueprint.assessment_blueprint_mappings.create!(competency_item: item, weight: weight) if item
    end
  end

  if blueprint_framework && osce_blueprint.blueprint_versions.none? { |version| version.blueprint_items.exists? }
    blueprint_version = osce_blueprint.draft_version || osce_blueprint.blueprint_versions.create!(
      competency_framework: blueprint_framework,
      version: (osce_blueprint.blueprint_versions.maximum(:version) || 0) + 1,
      status: "draft", change_notes: "Pemetaan awal ke komponen asesmen"
    )
    if blueprint_version.blueprint_items.empty?
      osce_method = AssessmentMethod.find_by!(code: "osce")
      component = blueprint_version.blueprint_items.create!(
        assessment_method: osce_method, code: "OSCE-CORE", title: "OSCE Komprehensif",
        assessment_context: "Blueprint OSCE keseluruhan program studi", weight: 100, position: 1
      )
      osce_blueprint.assessment_blueprint_mappings.includes(:competency_item).each do |mapping|
        component.blueprint_item_competencies.create!(
          competency_item: mapping.competency_item, assessment_weight: mapping.weight
        )
      end
    end
    blueprint_version.publish! if blueprint_version.status == "draft"
  end
end

# Fase 24 — Master Diagnosis (SKDI 2012 / ICD-10) & Keterampilan Klinis —
# contoh awal yang lazim di FKTP/FKRTL; admin menambah lewat UI atau impor CSV.
# Idempoten: nama yang sudah ada tidak diubah.
[
  [ "Demam tifoid", "A01.0", "4A", "Infeksi" ],
  [ "Demam dengue", "A90", "4A", "Infeksi" ],
  [ "Malaria", "B54", "4A", "Infeksi" ],
  [ "Tuberkulosis paru", "A15.0", "4A", "Respirasi" ],
  [ "Infeksi saluran pernapasan atas akut", "J06.9", "4A", "Respirasi" ],
  [ "Pneumonia", "J18.9", "4A", "Respirasi" ],
  [ "Asma bronkial", "J45.9", "4A", "Respirasi" ],
  [ "Penyakit paru obstruktif kronik", "J44.9", "3B", "Respirasi" ],
  [ "Hipertensi esensial", "I10", "4A", "Kardiovaskular" ],
  [ "Gagal jantung", "I50.9", "3B", "Kardiovaskular" ],
  [ "Angina pektoris", "I20.9", "3B", "Kardiovaskular" ],
  [ "Infark miokard akut", "I21.9", "3B", "Kardiovaskular" ],
  [ "Diabetes melitus tipe 2", "E11.9", "4A", "Endokrin" ],
  [ "Hipertiroid", "E05.9", "3A", "Endokrin" ],
  [ "Dislipidemia", "E78.5", "4A", "Endokrin" ],
  [ "Obesitas", "E66.9", "4A", "Endokrin" ],
  [ "Gastritis", "K29.7", "4A", "Gastrointestinal" ],
  [ "Gastroenteritis akut", "A09", "4A", "Gastrointestinal" ],
  [ "Apendisitis akut", "K35.8", "3B", "Gastrointestinal" ],
  [ "Hepatitis A", "B15.9", "4A", "Gastrointestinal" ],
  [ "Infeksi saluran kemih", "N39.0", "4A", "Urogenital" ],
  [ "Batu saluran kemih", "N20.9", "3A", "Urogenital" ],
  [ "Penyakit ginjal kronik", "N18.9", "2", "Urogenital" ],
  [ "Anemia defisiensi besi", "D50.9", "4A", "Hematologi" ],
  [ "Stroke iskemik", "I63.9", "3B", "Saraf" ],
  [ "Epilepsi", "G40.9", "3A", "Saraf" ],
  [ "Migrain", "G43.9", "4A", "Saraf" ],
  [ "Vertigo perifer", "H81.1", "4A", "Saraf" ],
  [ "Depresi", "F32.9", "3A", "Psikiatri" ],
  [ "Gangguan cemas menyeluruh", "F41.1", "3A", "Psikiatri" ],
  [ "Dermatitis atopik", "L20.9", "4A", "Kulit" ],
  [ "Skabies", "B86", "4A", "Kulit" ],
  [ "Urtikaria", "L50.9", "4A", "Kulit" ],
  [ "Konjungtivitis", "H10.9", "4A", "Mata" ],
  [ "Otitis media akut", "H66.9", "4A", "THT" ],
  [ "Tonsilitis akut", "J03.9", "4A", "THT" ],
  [ "Osteoartritis", "M19.9", "3A", "Muskuloskeletal" ],
  [ "Fraktur tertutup", "T14.2", "3B", "Muskuloskeletal" ],
  [ "Kehamilan normal", "Z34.9", "4A", "Obstetri" ],
  [ "Preeklamsia", "O14.9", "3B", "Obstetri" ],
  [ "Diare akut pada anak", "A09", "4A", "Anak" ],
  [ "Gizi kurang pada anak", "E44.1", "4A", "Anak" ]
].each do |name, code, level, group|
  DiagnosisDefinition.find_or_create_by!(name: name) { |d| d.icd10_code = code; d.skdi_level = level; d.system_group = group }
end

[
  [ "Pemasangan infus", "4A", "Prosedur Terapeutik" ],
  [ "Injeksi intramuskular", "4A", "Prosedur Terapeutik" ],
  [ "Injeksi intravena", "4A", "Prosedur Terapeutik" ],
  [ "Pungsi vena", "4A", "Prosedur Diagnostik" ],
  [ "Pemasangan kateter urin", "4A", "Prosedur Terapeutik" ],
  [ "Pemasangan NGT", "4A", "Prosedur Terapeutik" ],
  [ "Jahit luka", "4A", "Bedah Minor" ],
  [ "Insisi dan drainase abses", "4A", "Bedah Minor" ],
  [ "Ekstraksi kuku", "4A", "Bedah Minor" ],
  [ "Sirkumsisi", "4A", "Bedah Minor" ],
  [ "Pemasangan bidai", "4A", "Muskuloskeletal" ],
  [ "Resusitasi jantung paru", "4A", "Kegawatdaruratan" ],
  [ "Pemasangan oropharyngeal airway", "4A", "Kegawatdaruratan" ],
  [ "Pemeriksaan EKG", "4A", "Prosedur Diagnostik" ],
  [ "Interpretasi EKG", "4A", "Prosedur Diagnostik" ],
  [ "Pemeriksaan gula darah kapiler", "4A", "Prosedur Diagnostik" ],
  [ "Pemeriksaan rectal toucher", "4A", "Prosedur Diagnostik" ],
  [ "Pemeriksaan fundus mata", "4A", "Prosedur Diagnostik" ],
  [ "Pemeriksaan otoskopi", "4A", "Prosedur Diagnostik" ],
  [ "Pemeriksaan Leopold", "4A", "Obstetri" ],
  [ "Pertolongan persalinan normal", "4A", "Obstetri" ],
  [ "Pemasangan IUD", "4A", "Obstetri" ],
  [ "Nebulisasi", "4A", "Respirasi" ],
  [ "Pemasangan kanul oksigen", "4A", "Respirasi" ],
  [ "Pengambilan swab tenggorok", "4A", "Prosedur Diagnostik" ]
].each do |name, level, category|
  SkillDefinition.find_or_create_by!(name: name) { |s| s.skdi_level = level; s.category = category }
end

# Master Obat — daftar generik yang lazim dipakai di FKTP/FKRTL, untuk latihan
# menulis resep pada Logbook Kasus Klinis. Bukan katalog harga/stok apotek.
[
  [ "Parasetamol", "500 mg", "Tablet", "Analgesik-Antipiretik", "3-4 x 500 mg" ],
  [ "Parasetamol", "120 mg/5 mL", "Sirup", "Analgesik-Antipiretik", "10-15 mg/kgBB/kali" ],
  [ "Ibuprofen", "400 mg", "Tablet", "AINS", "3 x 400 mg p.c." ],
  [ "Asam mefenamat", "500 mg", "Tablet", "AINS", "3 x 500 mg p.c." ],
  [ "Amoksisilin", "500 mg", "Kapsul", "Antibiotik", "3 x 500 mg" ],
  [ "Amoksisilin", "125 mg/5 mL", "Sirup", "Antibiotik", "25-50 mg/kgBB/hari" ],
  [ "Sefiksim", "100 mg", "Kapsul", "Antibiotik", "2 x 100 mg" ],
  [ "Siprofloksasin", "500 mg", "Tablet", "Antibiotik", "2 x 500 mg" ],
  [ "Kotrimoksazol", "480 mg", "Tablet", "Antibiotik", "2 x 960 mg" ],
  [ "Eritromisin", "500 mg", "Tablet", "Antibiotik", "4 x 500 mg" ],
  [ "Metronidazol", "500 mg", "Tablet", "Antibiotik", "3 x 500 mg" ],
  [ "Omeprazol", "20 mg", "Kapsul", "Penghambat Pompa Proton", "1-2 x 20 mg a.c." ],
  [ "Ranitidin", "150 mg", "Tablet", "Antagonis H2", "2 x 150 mg" ],
  [ "Antasida", "200 mg", "Tablet", "Antasida", "3 x 1 tab a.c." ],
  [ "Domperidon", "10 mg", "Tablet", "Antiemetik", "3 x 10 mg a.c." ],
  [ "Ondansetron", "4 mg", "Tablet", "Antiemetik", "2-3 x 4 mg" ],
  [ "Oralit", "200 mL", "Suspensi", "Rehidrasi Oral", "Tiap diare cair" ],
  [ "Zinc", "20 mg", "Tablet", "Suplemen", "1 x 20 mg selama 10 hari" ],
  [ "Amlodipin", "10 mg", "Tablet", "Antihipertensi", "1 x 5-10 mg" ],
  [ "Kaptopril", "25 mg", "Tablet", "Antihipertensi", "2-3 x 12,5-25 mg a.c." ],
  [ "Lisinopril", "10 mg", "Tablet", "Antihipertensi", "1 x 10 mg" ],
  [ "Bisoprolol", "5 mg", "Tablet", "Beta-blocker", "1 x 2,5-5 mg" ],
  [ "Furosemid", "40 mg", "Tablet", "Diuretik", "1-2 x 40 mg" ],
  [ "Hidroklorotiazid", "25 mg", "Tablet", "Diuretik", "1 x 12,5-25 mg" ],
  [ "Simvastatin", "20 mg", "Tablet", "Statin", "1 x 20 mg malam" ],
  [ "Metformin", "500 mg", "Tablet", "Antidiabetik Oral", "2-3 x 500 mg p.c." ],
  [ "Glimepirid", "2 mg", "Tablet", "Antidiabetik Oral", "1 x 1-4 mg a.c." ],
  [ "Insulin human", "100 IU/mL", "Injeksi", "Insulin", "Sesuai titrasi" ],
  [ "Salbutamol", "2 mg", "Tablet", "Bronkodilator", "3 x 2-4 mg" ],
  [ "Salbutamol", "100 mcg/puff", "Inhalasi", "Bronkodilator", "2 puff bila sesak" ],
  [ "Ambroksol", "30 mg", "Tablet", "Mukolitik", "3 x 30 mg" ],
  [ "Setirizin", "10 mg", "Tablet", "Antihistamin", "1 x 10 mg malam" ],
  [ "Klorfeniramin maleat", "4 mg", "Tablet", "Antihistamin", "3 x 4 mg" ],
  [ "Deksametason", "0,5 mg", "Tablet", "Kortikosteroid", "3 x 0,5 mg p.c." ],
  [ "Metilprednisolon", "4 mg", "Tablet", "Kortikosteroid", "Sesuai indikasi" ],
  [ "Hidrokortison", "2,5%", "Krim", "Kortikosteroid Topikal", "2 x sehari oles tipis" ],
  [ "Mikonazol", "2%", "Krim", "Antijamur Topikal", "2 x sehari" ],
  [ "Permetrin", "5%", "Krim", "Antiskabies", "Oles 8-12 jam, ulangi 1 minggu" ],
  [ "Asam folat", "1 mg", "Tablet", "Suplemen", "1 x 1 mg" ],
  [ "Sulfas ferosus", "300 mg", "Tablet", "Suplemen Besi", "1-3 x 300 mg p.c." ],
  [ "Vitamin B kompleks", nil, "Tablet", "Suplemen", "1 x 1 tab" ],
  [ "Kloramfenikol", "0,5%", "Tetes", "Antibiotik Topikal Mata", "4-6 x 1 tetes" ],
  [ "Parasetamol", "1000 mg", "Infus", "Analgesik-Antipiretik", "3-4 x 1 g IV" ],
  [ "Ringer laktat", "500 mL", "Infus", "Cairan Kristaloid", "Sesuai kebutuhan" ]
].each do |name, strength, form, category, dosage|
  med = MedicationDefinition.find_or_initialize_by(name: name, strength: strength)
  med.assign_attributes(dosage_form: form, category: category, usual_dosage: dosage, active: true)
  med.save!
end

# Instalasi baru mulai dengan pendaftaran mandiri tertutup: akun dibuat admin
# lewat impor CSV. Instalasi lama (sudah ada akun) tidak diubah.
AppSetting.set_registration_open!(false, by: nil) if User.none? && !AppSetting.exists?(key: AppSetting::REGISTRATION_KEY)

# Instrumen supervisi disimpan terpisah menurut versi dan tujuan penggunaan.
# Chen dipakai untuk rekomendasi supervisi prospektif; Ottawa untuk bantuan
# yang benar-benar diberikan pada observasi retrospektif. Level tidak dipetakan
# menjadi padanan satu sama lain.
[
  {
    code: "chen_ume", name: "Chen entrustment scale (UME)", version_label: "2015",
    use_case: "prospective_entrustment",
    source_reference: "Chen et al. Acad Med. 2016;91:247-255. doi:10.1097/ACM.0000000000000988",
    levels: [
      ["not_allowed", "Belum diizinkan melakukan EPA", "Mahasiswa belum diizinkan melakukan aktivitas ini."],
      ["proactive_full", "Supervisi proaktif penuh", "Aktivitas dilakukan dengan supervisi penuh yang proaktif."],
      ["reactive_on_demand", "Supervisi reaktif/on-demand", "Supervisor segera tersedia saat diminta."],
      ["unsupervised", "Tanpa supervisi", "Aktivitas dapat dilakukan tanpa supervisi."],
      ["supervise_others", "Mensupervisi orang lain", "Dapat mensupervisi orang lain melakukan aktivitas."]
    ]
  },
  {
    code: "ottawa_oscore", name: "Ottawa O-SCORE entrustability scale", version_label: "2012",
    use_case: "retrospective_observation",
    source_reference: "Goffin et al. Acad Med. 2012;87(10):1401-1407. doi:10.1097/ACM.0b013e3182677805",
    levels: [
      ["did_for_learner", "Supervisor harus melakukan", "Supervisor mengambil alih atau melakukan aktivitas."],
      ["talked_through", "Supervisor memberi arahan terus-menerus", "Mahasiswa memerlukan arahan berkelanjutan selama aktivitas."],
      ["prompted", "Supervisor sesekali memberi prompt", "Mahasiswa bekerja cukup mandiri dengan prompt sesekali."],
      ["in_room_just_in_case", "Supervisor berada di ruangan", "Mahasiswa cukup mandiri; supervisor tetap hadir untuk keselamatan."],
      ["not_needed_present", "Supervisor tidak perlu hadir", "Mahasiswa bekerja mandiri dan menangani risiko dengan aman."]
    ]
  }
].each do |scale|
  levels = scale.delete(:levels)
  record = SupervisionScaleVersion.find_or_initialize_by(code: scale[:code], version_label: scale[:version_label])
  record.assign_attributes(scale)
  record.save!
  levels.each_with_index do |(code, label, description), index|
    record.supervision_levels.find_or_create_by!(code: code) do |level|
      level.ordinal = index + 1
      level.label = label
      level.description = description
    end
  end
end
