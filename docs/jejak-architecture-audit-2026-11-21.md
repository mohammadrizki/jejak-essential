# Audit dan Rancangan Konsolidasi Arsitektur JEJAK Essential

Tanggal: 21 November 2026  
Branch: unram  
Tahap: audit dan desain saja. Tidak ada perubahan schema, migration, model, route, atau perilaku aplikasi.

## Ringkasan

JEJAK sudah memiliki fondasi Core E-Portfolio: Peta Kompetensi per program studi dan berversi, Blueprint Asesmen berversi, Syarat Bukti hybrid, koleksi sumber bukti lokal, logbook, refleksi, halaman portofolio, serta model Capaian Kompetensi. Mini-CEX/DOPS dan alur observasi/promosi EPA juga ada. Integrasi yang terlihat sekarang terutama impor CSV/Glide untuk hasil ujian tertentu.

Arsitektur belum konsisten sebagai modular monolith berbatas domain. Gap utama adalah belum adanya kontrak bukti kanonik lintas Logbook/WPBA/EPA/sistem eksternal, alur kandidat artefak hingga Portofolio Terpilih, katalog instrumen WPBA berversi, konfigurasi aktivasi modul, assignment granular lintas modul, dan CCC EPA yang dikonfigurasi. EPA sekarang merupakan slice awal, bukan sistem final.

Repository aktif di branch unram dan working tree sudah berisi banyak perubahan lokal sebelumnya: navigasi, framework, template, Peta Artefak, EPA, test, dan migration. Schema kerja menunjukkan versi 2026_11_22_010005. Semua perubahan lokal dipertahankan. Tidak ada migration, pengujian, commit, atau operasi database yang dijalankan pada tahap desain ini.

## Dasar audit aktual

File yang diperiksa:

- Schema/migration: db/schema.rb; migration pemilikan kurikulum, desain kompetensi/asesmen, provenance framework, dan lima migration EPA terbaru.
- Model kurikulum/evidence: app/models/competency_framework.rb, competency_item.rb, competency_indicator.rb, assessment_blueprint.rb, blueprint_version.rb, blueprint_item.rb, evidence_requirement.rb, evidence_record.rb, competency_attainment.rb.
- Model aktivitas/WPBA/EPA: activity_log.rb, reflection_entry.rb, mini_cex_evaluation.rb, dops_evaluation.rb, assessment_event.rb, assessment_instance.rb, epa.rb, epa_competency.rb, epa_milestone.rb, epa_observation.rb, epa_promotion.rb, epa_promotion_review.rb, entrustment_decision.rb, supervision_scale_version.rb, supervision_level.rb.
- Otorisasi/navigasi: config/routes.rb, app/views/shared/_sidebar_nav.html.erb, app/policies/* dan controller terkait.
- docs/erd-final.md masih menggambarkan ERD kurikulum yang lebih lama dari schema terkini; perlu ditandai historis atau diperbarui setelah desain disetujui.

Kesimpulan berikut mengacu pada working tree, bukan jaminan bahwa perubahan lokal sudah dirilis.

## Inventaris kondisi

| Area | Sudah ada dan dapat digunakan | Gap utama |
|---|---|---|
| Peta Kompetensi | CompetencyFramework dimiliki StudyProgram; version/status/jenjang/provenance. CompetencyItem bertingkat dan berkode. CompetencyIndicator menyimpan kode, deskripsi, performance_level. Template dan deep-copy service tersedia. | Policy framework masih admin-sentris. Bukti/keputusan historis harus terikat konsisten pada versi peta. |
| Blueprint | Satu AssessmentBlueprint unik per program; BlueprintVersion dan BlueprintItem menyimpan versi/framework/metode/target/bobot/konteks; mapping kompetensi dan EPA ada. | AssessmentBlueprintMapping legacy berdampingan dengan model versi baru. Perlu strategi transisi/snapshot efektif. |
| Syarat Bukti | EvidenceRequirement mendukung blueprint/manual, target kompetensi/indikator/EPA, jenis sumber, minimum, validasi, hasil, keragaman kasus/penilai/kesempatan/tanggal, rentang waktu, independence group, critical dan kriteria tambahan. EvidenceRequirementProgress menghitung progres. | Operator kombinasi/alternatif, mutu bukti, safety, versi rule dan evaluasi historis perlu diformalkan. |
| EvidenceRecord | Tepat satu sumber lokal: AssessmentInstance, ActivityLog, ReflectionEntry atau EpaObservation; menyimpan tanggal, hasil, skor, feedback dan metadata. | MiniCexEvaluation/DopsEvaluation dan sumber eksternal belum menjadi source via kontrak bersama. Metadata tidak cukup untuk provenance, revisi dan version mapping. |
| Logbook | ActivityLog menyimpan tanggal, taksonomi, lokasi, rotasi, patient_code, deskripsi/refleksi/link dan verifikator; policy pemilik/verifier tersedia. | Juga menampung kegiatan non-klinis. Validasi aktivitas bukan validasi bukti kompetensi. Belum ada alur menjadi artefak terkurasi. |
| Refleksi | ReflectionEntry milik mahasiswa, dapat terkait logbook atau clinical case; CRUD tersedia. | Empat prompt baku dan relasi ke kompetensi, artefak, feedback, WPBA/EPA dan tindak lanjut belum menjadi kontrak konsisten. |
| WPBA | MiniCexEvaluation dan DopsEvaluation menyimpan mahasiswa, evaluator, rotasi, tanggal, kompleksitas, konteks, skor, feedback/status; controller/form/route/policy tersedia. | Belum ada katalog instrumen berversi yang konfigurabel, koreksi final beraudit, adapter EvidenceRecord atau assignment seragam. |
| EPA | EPA, EPACompetency many-to-many, EPAMilestone, skala versi/level, EpaObservation, EpaPromotion, EpaPromotionReview dan EntrustmentDecision tersedia. Skala observasi retrospektif dipisah dari target entrustment prospektif. Flag/promosi dan notifikasi preseptor tersedia. | Bukan CCC final: quorum/anggota diturunkan dari role Kaprodi, fallback admin, belum ada appointment/recusal/dissent/appeal dan workflow scope/review/revoke lengkap. Ordinal legacy 1–5 tetap ada. |
| Capaian | CompetencyAttainment menyimpan level/status/rationale/tanggal/pengambil keputusan. | Otoritas harus ditugaskan; keputusan perlu snapshot evidence dan tidak boleh otomatis dari sufficiency. |
| Integrasi | GlideSyncs/importer CBT/OSCE dan AssessmentEvent/AssessmentInstance menangani impor tertentu. | Belum ditemukan adapter SIA/Moodle/Examtool/OSCE, external ID map umum, canonical upsert atau revision audit. |
| Role/access | Devise, Role/UserRole, active_role, sejumlah Pundit policy; rotasi/kasus menjadi konteks penugasan. | Role bukan permission. Assignment belum seragam; sebagian controller memakai has_role? atau relasi longgar. Sidebar bukan kontrol akses. Role bawaan tenaga_kependidikan belum ditemukan. |
| Peta Artefak | Controller turunan dan halaman portfolio yang merangkum log, bukti dan requirement tersedia. | Belum ada candidate submission, review artefak, persetujuan tampil, curated selection dan izin publikasi terpisah. |

### Di luar ruang lingkup JEJAK

Jangan mengembangkan LMS, kursus/konten, presensi dan penjadwalan kelas, bank soal/engine CBT, atau engine pelaksanaan OSCE. SIA tetap menangani administrasi akademik lengkap. JEJAK menyimpan konteks akademik minimum dan bukti relevan saja.

## Batas domain modular yang disarankan

Tetap satu aplikasi Rails/PostgreSQL modular monolith; batas domain bukan Rails Engines atau microservices.

| Domain | Status | Tanggung jawab |
|---|---|---|
| Core E-Portfolio | wajib | Framework, blueprint, Expected Evidence, canonical evidence, refleksi/feedback, kurasi artefak, Portofolio Terpilih, kecukupan, attainment dan dashboard. |
| Logbook Klinis | opsional | Aktivitas profesional, peran, kompleksitas, supervisi, konteks minimal, validasi aktivitas; sumber bukti, bukan keputusan kompetensi. |
| WPBA | opsional | Mini-CEX, DOPS, CBD, observasi EPA dan instrumen berversi; hasil final dikirim ke Core. Tidak punya portofolio terpisah. |
| EPA | kontekstual/opsional | Unit kerja profesional, target supervisi, observasi longitudinal, dossier, promosi dan keputusan entrustment. Tidak sama dengan WPBA. Tidak wajib Sarjana; didukung Profesi/Spesialis/Subspesialis. |
| Integration Layer | adapter opt-in independen | SIA, Moodle, Examtool, OSCE hanya komunikasi dan transformasi; Core berjalan tanpa adapter. |
| Identity, Authorization & Assignment | layanan bersama | Role, permission, assignment/delegasi, scope akses dan audit. Devise tetap menjadi autentikasi. |

Menonaktifkan modul menghentikan input baru tetapi tidak menghapus data, bukti, keputusan, referensi atau hak baca historis yang diizinkan. EPA aktif memerlukan jalur observasi yang sah. Data historis tetap tunduk pada privacy dan assignment.

## ERD konseptual terpadu

Target relasi (konsep, bukan tabel yang diklaim sudah ada):

    Institution -> StudyProgram -> CompetencyFramework(version)
    FrameworkTemplate -> copied-to CompetencyFramework (provenance)
    CompetencyFramework -> CompetencyNode(parent-child) -> MeasurableIndicator
    StudyProgram -> AssessmentBlueprint -> BlueprintVersion -> BlueprintItem
    BlueprintItem <-> Indicator/Competency; BlueprintItem -> ExpectedEvidenceRule
    Indicator -> ExpectedEvidenceRule(manual); EPA -> ExpectedEvidenceRule
    EPA <-> CompetencyNode/Indicator through EPACompetency
    Learner -> LogbookEntry / WPBAObservation / Reflection
    SourceActivity -> CanonicalEvidence(source provenance, versioned mappings)
    CanonicalEvidence <-> ExpectedEvidenceRule; CanonicalEvidence <-> competencies
    CanonicalEvidence -> optional ArtifactSubmission -> PortfolioSelection
    ExpectedEvidenceRule -> SufficiencyEvaluation(snapshot)
    SufficiencyEvaluation informs (but does not decide) CompetencyAttainment
    EPA -> EPAObservation -> PromotionDossier -> PanelReview -> EntrustmentDecision
    User -> Assignment(scope, validity, delegation); User -> AuditEvent

CanonicalEvidence memiliki satu stable source activity identity sekalipun dipetakan ke banyak kompetensi/rule. Penghitungan independensi melihat source identity, bukan jumlah mapping. Sufficiency menyimpan versi rule, hasil, alasan, waktu dan sumber; keputusan attainment/entrustment adalah tindakan manusia berwenang dengan rationale dan evidence snapshot.

SourceActivity, CanonicalEvidence, ArtifactSubmission, PortfolioSelection, SufficiencyEvaluation, PromotionDossier, Assignment dan AuditEvent adalah konsep desain. Tidak ada migration yang diusulkan sekarang.

## Canonical Evidence dan kontrak lintas modul

| Bagian | Elemen kanonik |
|---|---|
| Provenance | source system, source record ID/revision, stable source activity ID, internal learner ID, waktu impor/sinkronisasi, reference/hash payload jika perlu. Upsert idempotent. |
| Akademik | program, periode/semester/kelas/rotasi bila tersedia, status saat peristiwa, otoritas sumber per atribut. |
| Asesmen | jenis/instrumen dan versi, event, waktu, skala dan skor/kategori, finalisasi/revisi, penilai, feedback dan validation state/actor/time. |
| Konteks | aktivitas/kasus, kompleksitas, peran, supervisi, lokasi/rotasi dengan minimisasi data klinis. Identitas pasien tidak masuk portofolio. |
| Pemetaan | kompetensi/indikator/EPA dan framework version, sumber/versi mapping, masa berlaku dan status verifikasi. |
| Artefak/privacy | reference ke sumber, versi, visibility dan consent; privat default, publikasi memerlukan izin terpisah. |

EvidenceRecord sekarang adalah relasi ke empat sumber lokal, bukan canonical schema penuh. Desain harus memilih source registry atau tabel sumber khusus serta service contract sebelum keputusan schema.

Kontrak:

- Logbook mengirim referensi dan ActivityValidated; Core tetap menilai EvidenceValidated.
- WPBA mengirim AssessmentFinalized dengan instrumen/version, skala, konteks, penilai, feedback dan revisi.
- EPA observation adalah satu sumber bukti; promosi/review/decision bukan observasi tambahan.
- Adapter eksternal mengirim normalized payload dengan status trusted atau needs_validation dan upsert idempotent.
- Core menghitung sufficiency saja; tidak membuat attainment otomatis.
- Semua domain meminta authorization dan assignment scope dari layanan bersama.

Evidence rule perlu versi, operator (semua/alternatif/kombinasi), sumber, minimum, kualitas/hasil, keragaman kasus/penilai/waktu/kesempatan, rentang waktu, critical/safety dan independence scope. Satu aktivitas boleh mendukung beberapa kompetensi tetapi tidak menjadi beberapa kesempatan independen dalam independence group yang sama. Perubahan rule membuat evaluasi versi baru, bukan menulis ulang histori.

## Integrasi opsional dan data akademik

Importer CBT/OSCE dan Glide yang ada adalah landasan file import, bukan adapter umum. Pertahankan kompatibilitas.

| Sumber | Data relevan | Strategi |
|---|---|---|
| SIA | identitas, prodi/jenjang, periode, kelas/member, status mahasiswa/dosen | Manual tetap tersedia; CSV/XLSX staging dengan preview, reconciliation dan error report; API bila disetujui. Otoritas sumber per atribut. |
| Moodle | referensi tugas/artefak pilihan, hasil final, feedback/refleksi pilihan | API/webhook bila ada; file fallback. Tidak menyinkronkan konten, jadwal atau presensi. |
| Examtool | exam ID, hasil, skor/kategori, domain bila ada, finalization/revision | API/webhook atau staging CSV/XLSX. Tidak mengelola bank soal. |
| OSCE | exam/station ID, hasil per peserta/station/domain, feedback/finalization | API/pertukaran file dan mapping versi framework. Tidak melaksanakan station. |

Mode manual, impor dan integrasi SIA bisa dikombinasikan per data. JEJAK memakai ID internal stabil; external ID dipetakan dengan issuer, bukan nama. Tidak ada FK wajib ke sistem luar. Perubahan status akademik tidak menghapus bukti historis.

## Logbook, artefak, refleksi dan portofolio

Alur target: Catatan Logbook → Validasi Aktivitas → Kandidat Artefak mahasiswa (alasan pemilihan/refleksi opsional) → Pengajuan → Telaah relevansi, privacy dan izin tampil → Portofolio Terpilih. Evidence dapat memenuhi requirement walau tidak dipilih tampil. Simpan reference ke logbook/version, bukan salinan seluruh isi. Portfolio privat default; persetujuan akademik bukan izin publikasi.

Empat keputusan tetap berbeda: validasi aktivitas, validasi bukti, persetujuan tampil sebagai artefak, keputusan capaian. ActivityLog punya verifier; workflow artefak belum terlihat.

Ganti menu Pengalaman Belajar dengan Refleksi Pengalaman Belajar. Prompt: Apa yang saya alami? Apa yang saya pelajari? Apa yang masih perlu saya perbaiki? Apa yang akan saya lakukan selanjutnya? Refleksi tidak otomatis wajib di setiap kegiatan; Expected Evidence dapat mewajibkannya. Hubungkan opsional ke kompetensi, artefak, logbook, asesmen, WPBA/EPA, feedback dan tindak lanjut.

## WPBA

MiniCexEvaluation dan DopsEvaluation saat ini memakai dimensi/skor tetap dan JSON. Pertahankan hasil historis melalui instrument version snapshot sebelum refactor. Katalog target memuat tujuan, versi, komponen/rubric, skala berlabel, required fields, aturan finalisasi dan mapping kompetensi/EPA. Skala instrumen berbeda tidak disamakan hanya karena ordinal.

Form mobile: pilih mahasiswa dari assignment aktif → instrumen/konteks → kompleksitas/peran/supervisi → rating/narasi → preview → draft/final. Hasil final immutable; koreksi berupa amendment beralasan. Feedback/follow-up terlihat bagi mahasiswa. Hasil menjadi source evidence melalui Core, bukan keputusan otomatis.

## EPA: gap analysis dan desain lanjutan

Model yang ditemukan:

- EPA menyimpan scope/limitations/risk sebagai teks, kode, judul dan status.
- EPACompetency memetakan EPA ke kompetensi/indikator, contribution, prerequisite, KSA dimension, minimum attainment dan critical.
- EPAMilestone menyimpan jenjang/target.
- SupervisionScaleVersion/Level memisahkan retrospective observation dari prospective entrustment; seed Chen/Ottawa merujuk sumber masing-masing.
- EpaObservation menyimpan learner/EPA/observer/case/rotation/level/tanggal/kompleksitas/scope/narasi/strengths/areas-to-improve/safety/status. Observasi recorded dapat tertaut ke requirement.
- EpaPromotionReadiness memeriksa mandatory/critical evidence dan unresolved safety. Promotion/review/decision tersedia.
- BlueprintItemEPA, EvidenceRequirement dan portfolio memiliki kaitan EPA.

Kesenjangan:

1. Katalog/template EPA dan salinan program belum dipisahkan; scope aktivitas, batas kewenangan dan prasyarat belum cukup terstruktur.
2. KSA satu dimensi per mapping; perlu keputusan apakah satu atau beberapa dimensi/kriteria.
3. Target lintas jenjang/program dan versioning belum lengkap.
4. Chen/Ottawa harus mempertahankan definisi/anchor masing-masing; ordinal bukan konversi otomatis.
5. EpaObservation bukan WPBA generik dan tidak langsung mereferensikan AssessmentEvent/BlueprintItem/instrumen.
6. Status/koreksi/return/void perlu transisi permission dan audit.
7. Belum ada dossier longitudinal lengkap untuk variasi kasus/penilai/waktu, trend, safety dan gap.
8. CCC memakai Kaprodi yang terdeteksi, fallback admin, dan quorum sederhana; tidak ada appointment/recusal/conflict/dissent lengkap. Admin teknis tidak otomatis pemutus akademik.
9. Defer, restricted scope, review due, appeal dan revoke belum workflow lengkap.
10. EntrustmentDecision masih memiliki LEVELS 1–5/compatibility mapping; bukan definisi Chen/Ottawa.
11. Permission observer, preseptor, reviewer, panel/chair, final authority dan learner belum dikelola lewat assignment pusat.
12. Dashboard longitudinal kecukupan/kesenjangan supervisi belum lengkap.

State machine desain:

- Observasi formatif: draft → submitted → recorded; submitted → returned → resubmitted; recorded hanya dikoreksi/dibatalkan melalui event revisi beralasan. Safety triage terpisah dari rating.
- Dossier: not_ready → eligible_flagged → preceptor_review → promoted_to_authority → panel_review → deferred/needs_evidence | not_entrusted | entrusted_with_scope | entrusted | restricted → review_due → renewed/restricted/revoked.
- Eligibility bukan keputusan. Preseptor meninjau/endorses atau menahan dengan alasan. Panel memeriksa dossier snapshot dan dissent. Hanya final authority mengesahkan. Rata-rata skor tidak menentukan keputusan.

Flag dan promosi-preseptor tersedia sebagai slice awal. Lanjutan perlu assignment penerima tepat, dedupe/escalation, dossier dan status panel terlihat, tanpa menyamakan kesiapan dengan izin praktik.

## Role, permission dan assignment

User memakai Devise dan Role/UserRole dengan active_role. Pertahankan role lama: admin, kaprodi, dosen, preseptor, mahasiswa. Tambahkan tenaga_kependidikan setelah tugasnya disepakati. Role = kapasitas; permission = aksi; assignment = objek/lingkup dan masa berlaku. Default deny, server-side scope, audit grant/revoke dan keputusan. Admin teknis tidak otomatis mendapat hak attainment decision atau EPA final authority.

| Role | Akses yang disarankan |
|---|---|
| Mahasiswa | Data sendiri: target kompetensi, koleksi, refleksi, artifact submission, feedback, sufficiency, attainment dan EPA yang relevan; tidak mengesahkan bukti sendiri. |
| Preseptor | Learner/rotasi assigned: validasi logbook, WPBA/EPA observation, feedback dan kesiapan promosi; bukan keputusan final default. |
| Dosen | Cohort/mahasiswa assigned: feedback, evidence review, WPBA/panel sesuai assignment. |
| Kaprodi | Peta/blueprint program dan analitik; keputusan/panel hanya dengan appointment. |
| Tenaga Kependidikan | Rekonsiliasi roster/import/data minimum bila ditugaskan; tanpa narasi klinis/refleksi/keputusan secara default. |
| Administrator | Konfigurasi teknis, identitas, integrasi/import/log; konten sensitif/keputusan hanya dengan grant khusus beraudit. |

Policy Pundit yang ada menjadi titik migrasi, tetapi tiap index/show/mutation harus menerapkan scope assignment. Penyembunyian menu bukan otorisasi.

## Navigasi target enam role

Modul nonaktif, jenjang tidak relevan atau tiada assignment berarti tautan tidak ditampilkan. Direct URL tetap ditolak server-side.

| Role | Menu tujuan kerja |
|---|---|
| Mahasiswa | Dashboard Saya; Target Kompetensi (Peta Saya, Peta Artefak, Syarat Bukti); Portofolio Saya (Koleksi, Refleksi Pengalaman Belajar, Pengajuan Artefak, Portofolio Terpilih, Umpan Balik); Logbook jika aktif; WPBA jika berwenang; EPA hanya Profesi/Spesialis/Subspesialis; Capaian Saya (kecukupan, attainment, gap/tindak lanjut). |
| Preseptor | Dashboard dan antrean learner assigned; validasi Logbook; WPBA; Observasi EPA/flag promosi; feedback/tindak lanjut. |
| Dosen | Dashboard cohort; target/peta; Koleksi Bukti dan feedback; WPBA/penilaian; kecukupan/keputusan hanya dengan permission. |
| Kaprodi | Dashboard capaian/gap program; Pustaka/Peta Kompetensi; Blueprint/Expected Evidence; review/panel saat appointed; evaluasi mutu dan tindak lanjut. |
| Tenaga Kependidikan | Rekonsiliasi identitas/roster/import yang diotorisasi dan laporan error; tanpa konten klinis default. |
| Administrator | Konfigurasi, pengguna/role, integrasi/import dan audit teknis; bukan panel akademik otomatis. |

Pemetaan route lama: activity_logs/kalender → Logbook/Koleksi; clinical_cases → konteks/validasi; reflection_entries/student feedback journal → Refleksi & Umpan Balik; DOPS/Mini-CEX/assessment forms → WPBA/penilaian; student assessments/exam scores/CBT/OSCE imports → hasil/bridge eksternal, bukan engine ujian. Rotations, tutorials, learning_units, evaluation_schedules dan final_projects perlu ditinjau karena sebagian konteks/assignment dan sebagian mendekati administrasi/pembelajaran luar lingkup. Jangan menghapus route/data tanpa dependency review.

Sidebar empat tahap OBE sudah ada di app/views/shared/_sidebar_nav.html.erb, tetapi masih memiliki kelompok Pengalaman Belajar, menu lama dan cakupan administratif lebih luas. Perubahan harus memakai matriks role×permission×module×stage×assignment, bukan relabel saja. Mobile nav/breadcrumb perlu bersumber dari aturan yang sama.

## File aktual yang mungkin terdampak setelah persetujuan (belum diubah)

| Area | Titik aktual | Arah |
|---|---|---|
| Core/framework | competency_framework.rb, competency_item.rb, competency_indicator.rb, competency_framework_duplicator.rb, schema.rb | konsistensi clone/version dan historical reference. |
| Blueprint/evidence | assessment_blueprint.rb, blueprint_version.rb, blueprint_item.rb, evidence_requirement.rb, evidence_record.rb, evidence_requirement_progress.rb | canonical provenance, rule version, sufficiency snapshot; jaga mapping lama. |
| WPBA | mini_cex_evaluation.rb, dops_evaluation.rb, controllers/forms/routes/policies | katalog instrument version, correction history, assignment dan Evidence adapter. |
| Logbook/portfolio/reflection | activity_log.rb, reflection_entry.rb, portfolios_controller.rb serta routes/views | candidate/review/selection/privacy dan prompt refleksi. |
| EPA | model EPA di atas, controllers/services/views/routes dan lima migration terkini | CCC/appointment/dossier/decision lifecycle; hanya sesudah desain EPA disetujui. |
| Access | user.rb, role.rb, user_role.rb, clinical_rotation.rb, clinical_case.rb, app/policies/* | permission/assignment/Tendik/audit; Devise dan role lama dipertahankan. |
| Integrasi | admin/glide_syncs_controller.rb, importer services, AssessmentEvent/Instance, StudyProgram/User | staging, external ID map, adapter, revision; tanpa FK eksternal wajib. |
| Navigasi | navigation_helper.rb, shared sidebar/mobile views, config/routes.rb, navigation tests | capability-based menu; URL tetap terlindungi. |

Tidak ada perubahan schema yang disetujui atau dibuat.

## Rencana bertahap setelah persetujuan

1. Keputusan desain, baseline schema/test report, vocabulary, privacy dan source of truth.
2. Stabilkan Core: framework/blueprint version, clone, published immutability, expected-evidence semantics.
3. Evidence contract, provenance, idempotency, correction audit dan mapping version.
4. Konfigurasi modul serta mode manual/import/SIA dan external identity reconciliation.
5. Authorization/assignment dan navigasi enam role, termasuk Tendik.
6. Logbook→candidate→review→Portofolio Terpilih dan refleksi.
7. WPBA instrument catalog/mobile workflow dan adapter Evidence.
8. Adapter eksternal opsional sesuai API/file aktual.
9. Persetujuan desain EPA/CCC, kemudian implementasi bertahap.
10. Sufficiency longitudinal, dashboard gap dan keputusan attainment yang tetap human-led.

Evidence contract/assignment dibutuhkan sebelum WPBA/EPA penuh. Desain EPA boleh paralel; implementasi menunggu persetujuan desain khususnya.

Pengujian mendatang: clone/version/published immutability; kompatibilitas historis; idempotent import/revision; dedupe independence; pemisahan validasi; direct URL/assignment/privacy; role/menu matrix; module off dengan read history; logbook-artifact provenance; WPBA final/correction; EPA jenjang Sarjana, no mean-based decision, quorum/recusal/defer/restrict/revoke, safety dan versioned scales.

## Keputusan yang masih perlu pemilik produk

1. Apakah multi-institution bagian scope sekarang atau masa depan? StudyProgram belum memiliki FK institution.
2. Apakah hierarchy selalu domain→kompetensi→subkompetensi→indikator, atau indikator dapat terkait pada kompetensi maupun subkompetensi?
3. Bagaimana framework version mengikat Blueprint dan mahasiswa saat peta berubah?
4. Bolehkah evidence sama memenuhi indikator berbeda; di mana independensi harus berlaku?
5. Sumber mana dipercaya otomatis; kapan hasil impor membutuhkan validasi?
6. Siapa menyetujui artefak untuk tampilan internal/publikasi; aturan retensi/withdrawal?
7. Data klinis minimum, case pseudonym, retention dan break-glass untuk panel?
8. Siapa memberi assignment dosen/preseptor/cohort; sumber manual/import/SIA dan aturan expiry/delegation?
9. Tugas Tendik dan field yang boleh dilihat?
10. EPA: komposisi CCC/final authority, pemicu promosi, quorum/dissent/recusal/appeal, scope, review/expiry/revoke dan safety escalation?
11. Observasi eksternal apa yang sah untuk EPA bila WPBA JEJAK tidak aktif?
12. Produk/versi dan API/file aktual SIA/Moodle/Examtool/OSCE?
13. Status produk untuk rotations, tutorials, learning_units, evaluation schedules, final projects, CBT imports, calendar dan SRQ? Jangan menghapus tanpa dependency review.
14. Definisi attainment level, pemisahan rekomendasi/pengesahan serta review/koreksi keputusan?

## Kesimpulan

Core, Logbook, sebagian WPBA dan workflow EPA parsial telah ada. Prioritas konsolidasi adalah provenance/versioning, kontrak bukti, pemisahan validasi aktivitas/bukti/sufficiency/keputusan, assignment/permission bersama dan alur artefak. EPA tetap mandat desain khusus yang belum selesai; flag promosi dan panel sekarang hanya titik awal.

Tahap ini tidak melakukan refactoring, migration, perubahan autentikasi atau penghapusan data. Perubahan struktural dimulai setelah keputusan desain dan batas schema disetujui.
