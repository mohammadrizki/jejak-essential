# ERD final JEJAK Essential: Kurikulum

Keputusan: peta kompetensi dimiliki satu program studi; tiap program studi memiliki satu blueprint keseluruhan; cakupannya berlaku untuk semua jenjang (Sarjana, Profesi, Spesialis, Subspesialis); expected evidence memakai bentuk hybrid (jenis bukti terstruktur dan catatan bebas).

```mermaid
erDiagram
  STUDY_PROGRAMS ||--o| COMPETENCY_FRAMEWORKS : "memiliki peta kompetensi"
  STUDY_PROGRAMS ||--o| ASSESSMENT_BLUEPRINTS : "memiliki blueprint"
  COMPETENCY_FRAMEWORKS ||--|{ COMPETENCY_ITEMS : "memuat"
  COMPETENCY_ITEMS ||--o{ COMPETENCY_ITEMS : "parent / child"
  ASSESSMENT_BLUEPRINTS ||--o{ ASSESSMENT_BLUEPRINT_MAPPINGS : "membobot"
  COMPETENCY_ITEMS ||--o{ ASSESSMENT_BLUEPRINT_MAPPINGS : "dipetakan"
  STUDY_PROGRAMS ||--o{ LEARNING_UNITS : "menyelenggarakan"
  ASSESSMENT_BLUEPRINTS o|--o{ LEARNING_UNITS : "menjadi acuan"
  COMPETENCY_ITEMS {
    bigint id PK
    bigint competency_framework_id FK
    bigint parent_id FK
    string title
    text expected_evidence_text
    jsonb expected_evidence_types
  }
  COMPETENCY_FRAMEWORKS {
    bigint id PK
    bigint study_program_id FK UK
    string name
  }
  ASSESSMENT_BLUEPRINTS {
    bigint id PK
    bigint study_program_id FK UK
    string name
    jsonb learning_outcomes
  }
  ASSESSMENT_BLUEPRINT_MAPPINGS {
    bigint id PK
    bigint assessment_blueprint_id FK
    bigint competency_item_id FK
    decimal weight
  }
```

`study_programs.competency_framework_id` tetap dipertahankan sebagai pilihan kerangka Peta EPA yang sudah ada. Kolom itu berbeda makna dari `competency_frameworks.study_program_id`, yang menetapkan pemilik Peta Kompetensi. Ini mencegah perubahan keputusan Peta EPA yang telah dipakai pada entrustment.

Expected Evidence hybrid disimpan pada setiap simpul kompetensi: `expected_evidence_types` berisi nol atau lebih kode baku (`observasi`, `artefak`, `asesmen`, `refleksi`), sementara `expected_evidence_text` menampung konteks/catatan bebas. Tidak ada bukti aktual mahasiswa di kolom ini; unggahan bukti aktual tetap menjadi data logbook/asesmen.

Blueprint wajib dimiliki tepat satu prodi dan indeks unik membatasi satu blueprint per prodi. Blueprint hanya dapat memetakan simpul dari Peta Kompetensi prodi yang sama; validasi model menegakkan konsistensi pasangan ini. Learning Unit tetap dapat merujuk blueprint prodi itu.

## Migration

`20261120010001_scope_curriculum_to_study_programs` menambahkan FK pemilik pada peta dan blueprint, mengisi data lama (peta pertama ke PSSK; blueprint memakai prodi Learning Unit terbanyak atau PSPD sebagai fallback), lalu membuat FK wajib. Migration juga menambahkan dua kolom Expected Evidence hybrid. Referensi kerangka Peta EPA lama tidak diubah. Jenjang tidak disimpan sebagai enum database, sehingga penambahan prodi di jenjang apa pun tidak mengubah relasi kurikulum.
