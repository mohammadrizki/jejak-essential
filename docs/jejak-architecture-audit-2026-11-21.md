# Audit dan Rancangan Konsolidasi Arsitektur JEJAK Essential

Tanggal audit terakhir: 22 November 2026
Branch: unram
Status: implementasi terpadu pada working tree. Core evidence, portofolio terkurasi, konfigurasi modul, katalog WPBA, assignment, dan workflow CCC EPA tersedia. Integrasi jaringan eksternal memerlukan kontrak sistem sumber dan kebijakan akademik lokal.

## Status implementasi setelah konsolidasi

Perubahan terbaru pada working tree menambahkan:

- Pengajuan artefak dari logbook terverifikasi, refleksi, atau bukti tervalidasi; telaah append-only; dan Portofolio Terpilih privat yang menyimpan referensi ke sumber, bukan salinan narasi klinis.
- Assignment berbatas program/mahasiswa/rotasi untuk penelaah artefak, pemvalidasi logbook, penilai WPBA, panel EPA, pengusul capaian, dan pengambil keputusan capaian. Perubahan penting dicatat dengan riwayat.
- Katalog instrumen WPBA berversi mencakup Mini-CEX, CEC, CWS, BPE, DOPS, CbD, dan MSF. Observasi EPA memiliki alur tersendiri dan tidak ditawarkan sebagai instrumen WPBA; hasil WPBA terkirim tidak dapat ditimpa.
- Pemetaan ID eksternal yang tidak bergantung pada nama, audit rekonsiliasi, adapter layanan SIA/Moodle/Examtool/OSCE/WPBA klinis eksternal, serta upsert bukti kanonik yang idempoten. Semua integrasi tetap nonaktif secara default dan belum merupakan konektor jaringan siap produksi.
- Refleksi empat prompt dengan tautan kompetensi dan bukti milik penulis secara opsional; tautan bukti tidak membuat evidence record baru.
- Workflow CCC EPA memisahkan rekomendasi panel dari pengesahan Ketua Panel; quorum tidak otomatis menjadi keputusan. Conflict/recusal, alternatif suara/dissent, snapshot dossier, keberatan mahasiswa per ronde, tenggat tinjauan ulang, serta hasil final ber-audit tersedia.
- Usulan capaian kompetensi dengan snapshot versi framework dan bukti, keputusan eksplisit oleh pengambil keputusan yang ditugaskan, serta riwayat review immutable.
- Perhitungan kecukupan bukti berbatas mahasiswa pada halaman portofolio, kesiapan promosi EPA, dan snapshot keputusan; bukti mahasiswa lain tidak ikut memenuhi requirement.
- Snapshot Syarat Bukti immutable; setiap EvidenceRecord ditautkan ke versi yang digunakan mahasiswa. Snapshot keputusan hanya memuat bukti yang lolos aturan.
- Provenance artefak ringan dan immutable. Pengajuan menyimpan referensi/versi sumber tanpa menggandakan narasi klinis; sumber yang dipakai pengajuan tidak dapat dihapus melalui aplikasi.
- Quorum EPA dapat dikonfigurasi per program studi. Anggota panel, pembaca dossier, dan penangan flag keselamatan EPA harus ditugaskan eksplisit. Pencabutan entrustment tersedia lewat panel dan tersimpan sebagai keputusan historis.
- Assignment memvalidasi jenis lingkup, target program studi, aktor, dan masa berlaku; pencabutan mencatat aktor serta waktunya.
- Akses dossier klinis, Logbook, dan EPA diketatkan: admin teknis tanpa assignment tidak melihat catatan klinis atau keputusan; pembimbing/penilai yang ditugaskan tetap dapat membuka lingkupnya. Penilaian ujian tidak diberikan oleh role admin saja.
- CCC EPA kini memisahkan rekomendasi anggota dari pengesahan Ketua Panel yang ditugaskan. Dossier snapshot, konflik yang memicu recusal permanen per ronde, suara dissent, keberatan append-only per ronde, dan tenggat tinjauan ulang tercatat.
- Dashboard EPA memperlihatkan status kecukupan per Syarat Bukti, keragaman penilai/kasus/tanggal, sebaran level supervisi, dan flag keselamatan secara terpisah dari keputusan.

Migration baru untuk EvidenceRequirementVersion, quorum panel, provenance artefak, dan audit assignment telah dijalankan pada database test lokal. Semua migration memakai transaksi PostgreSQL standar; perubahan FK dibagi menjadi penambahan NOT VALID dan validasi pada migration terpisah. Tidak ada migration production yang dijalankan.

Verifikasi terakhir: 774 tes, 4.502 assertion, 0 failure, 0 error, 0 skip. `zeitwerk:check`, `git diff --check`, dan status migration pada `jejak_essential_test` lulus. Database yang digunakan hanya `jejak_essential_test`.

## Ringkasan

JEJAK sudah memiliki fondasi Core E-Portfolio: Peta Kompetensi dan Blueprint berversi, Syarat Bukti hybrid/versioned, canonical EvidenceSource, logbook, refleksi, kurasi portofolio, dan Capaian Kompetensi. Mini-CEX/DOPS/CBD, katalog WPBA berversi, serta alur observasi/promosi EPA juga tersedia. Adapter eksternal melakukan normalisasi dan ingest payload; konektor jaringan belum dihubungkan ke vendor tertentu.

Arsitektur tetap modular monolith; pemisahan domain saat ini berupa service, model, policy, dan controller di satu Rails app, belum boundary package yang ditegakkan otomatis. Gap tersisa terutama adapter jaringan, kontrak impor/staging tiap vendor, pengingat/renewal entrustment, dan panel analitik longitudinal penuh.

Repository aktif di branch unram dan working tree berisi perubahan lokal berlapis: navigasi, framework, template, Peta Artefak, EPA, test, dan migration. Semua perubahan lokal dipertahankan. Tidak ada commit, push, deployment, atau operasi database production.

## Dasar audit aktual

File yang diperiksa:

- Schema/migration: db/schema.rb; migration pemilikan kurikulum, desain kompetensi/asesmen, provenance framework, dan lima migration EPA terbaru.
- Model kurikulum/evidence: app/models/competency_framework.rb, competency_item.rb, competency_indicator.rb, assessment_blueprint.rb, blueprint_version.rb, blueprint_item.rb, evidence_requirement.rb, evidence_record.rb, competency_attainment.rb.
- Model aktivitas/WPBA/EPA: activity_log.rb, reflection_entry.rb, mini_cex_evaluation.rb, dops_evaluation.rb, assessment_event.rb, assessment_instance.rb, epa.rb, epa_competency.rb, epa_milestone.rb, epa_observation.rb, epa_promotion.rb, epa_promotion_review.rb, entrustment_decision.rb, supervision_scale_version.rb, supervision_level.rb.
- Otorisasi/navigasi: config/routes.rb, app/views/shared/_sidebar_nav.html.erb, app/policies/* dan controller terkait.
- docs/erd-final.md masih menggambarkan ERD kurikulum yang lebih lama dari schema terkini; perlu ditandai historis atau diperbarui setelah desain disetujui.

Kesimpulan audit mengacu pada working tree, bukan jaminan bahwa perubahan lokal sudah dirilis.

## Perubahan fondasi setelah rancangan

Fondasi berikut telah diterapkan pada working tree. Migration terbaru telah dijalankan pada database lokal `jejak_essential_test`; migration production tidak dijalankan:

- `EvidenceSource` menjadi snapshot sumber bukti kanonis dengan sistem/record/revisi, activity key stabil, mahasiswa, penilai, instrumen, konteks, status validasi, dan provenance. `CanonicalEvidenceIngestor` melakukan upsert idempoten untuk requirement bertipe `external`; payload revisi yang sama tetapi berubah ditolak.
- `EvidenceRecord` kini dapat menunjuk ke sumber Mini-CEX, DOPS, atau `EvidenceSource`. Perhitungan Syarat Bukti memakai activity key untuk deduplikasi revisi/independensi. Validasi sumber eksternal memperbarui hasil evidence terkait dalam transaksi.
- Mini-CEX dan DOPS yang sudah dikirim dapat menjadi bukti WPBA. Formulir penilai dibatasi dengan assignment rotasi aktif dan kepemilikan mahasiswa.
- `ModuleConfiguration` mengatur aktivasi Logbook, WPBA, EPA, dan adapter per program studi, dengan riwayat perubahan append-only di `ModuleConfigurationChange`. Mematikan Logbook menghentikan formulir baru/edit pada ActivityLog dan ClinicalCase melalui controller, sementara riwayat dan penyelesaian verifikasi tertunda tetap tunduk pada policy. WPBA/EPA menghentikan input observasi baru tetapi tetap menyediakan baca historis sesuai otorisasi. Core selalu aktif; EPA dapat diaktifkan opsional pada Sarjana maupun jenjang lain.
- Kaprodi dibatasi pada framework dan blueprint program studinya pada controller/policy yang disentuh.
- Resolusi flag keselamatan EPA menghasilkan snapshot sumber baru; record bukti diarahkan ke revisi baru sebelum readiness dihitung ulang.
- Syarat Bukti mempunyai snapshot JSON immutable. EvidenceRecord lama dibackfill ke versi awal dan bukti mahasiswa berikutnya tetap memakai versi pertama yang berlaku untuknya; evaluasi dan keputusan memakai konfigurasi versi tersebut.
- Snapshot Capaian Kompetensi hanya membawa EvidenceRecord yang lolos evaluasi sufficiency.
- Submission artefak memegang provenance minimal. Isi sumber klinis tidak disalin; sumber yang ditautkan dilindungi dari penghapusan via aplikasi.
- Anggota panel, akses dossier, penyelesaian flag keselamatan, dan reviewer artefak memerlukan assignment aktif. Quorum komite EPA disimpan di konfigurasi program studi; revoke menyimpan aktor dan waktu.

Migration tambahan meliputi governance panel EPA, audit batch impor eksternal, relasi renewal EPA, koreksi WPBA, observasi WPBA berversi, tautan refleksi-bukti, serta lifecycle entrustment dan event audit. File memakai timestamp Rails 14 digit. Fresh-install verification dijalankan pada database PostgreSQL audit terpisah. Tidak ada concurrent index atau `disable_ddl_transaction!` pada `db/migrate`.

### Verifikasi

Verifikasi untuk revisi akses terbaru dicatat setelah suite penuh selesai dijalankan. Setiap kegagalan baru ditangani sebagai regresi kode atau diperbarui hanya jika ekspektasi lama bertentangan langsung dengan kebijakan akses berbasis assignment.

Ini adalah fondasi, bukan implementasi keseluruhan arsitektur. Lihat gap yang masih ada pada bagian akhir dokumen.

## Inventaris kondisi

| Area | Sudah ada dan dapat digunakan | Gap utama |
|---|---|---|
| Peta Kompetensi | CompetencyFramework dimiliki StudyProgram; version/status/jenjang/provenance. CompetencyItem bertingkat dan berkode. CompetencyIndicator menyimpan kode, deskripsi, performance_level. Template dan deep-copy service tersedia. | Pengikatan historis ke peta perlu dipastikan untuk setiap jalur legacy yang belum menggunakan snapshot. |
| Blueprint | Satu AssessmentBlueprint unik per program; BlueprintVersion dan BlueprintItem menyimpan versi/framework/metode/target/bobot/konteks; mapping kompetensi dan EPA ada. | AssessmentBlueprintMapping legacy berdampingan dengan model versi baru. Perlu strategi transisi/snapshot efektif. |
| Syarat Bukti | Hybrid blueprint/manual, target kompetensi/indikator/EPA, minimum dan keragaman, independence group, critical criteria, evaluasi per mahasiswa dan snapshot versi immutable tersedia. | Semantik kombinasi AND/OR alternatif dan rubric mutu lintas skala belum digeneralisasi; kriteria bebas tetap meminta telaah manusia. |
| EvidenceRecord | Sumber local/WPBA/eksternal dibungkus EvidenceSource kanonik dengan activity identity, provenance, status validasi, revision, dan mapping; record terikat ke versi requirement. | Jalur koreksi/finalisasi dari seluruh sistem sumber belum satu kontrak, importer legacy masih berdampingan. |
| Logbook | ActivityLog tervalidasi dapat dipilih sebagai bukti dan kandidat artefak; modul dapat dinonaktifkan tanpa menghapus riwayat. | Validasi aktivitas tetap terpisah dari validasi bukti dan keputusan kompetensi. Sebagian taksonomi juga mencakup kegiatan non-klinis. |
| Refleksi | Empat prompt, relasi kompetensi, logbook/kasus, dan pengajuan artefak privat tersedia. | Feedback/tindak lanjut lintas modul belum berupa satu workflow yang konsisten. |
| WPBA | Mini-CEX/DOPS/CBD/EPA memiliki katalog definisi instrumen berversi, form evaluator, assignment, dan kaitan EvidenceSource. Mini-CEX/DOPS terkirim dapat dikoreksi melalui revisi beralasan. Instrumen tambahan dapat memiliki komponen rating/text/select/boolean yang tervalidasi, observasi mobile-friendly, dan versi terbit immutable; observasi dapat ditautkan ke Syarat Bukti dan portofolio. | Governance klinis, kebijakan amendment institusional, serta jenis komponen yang lebih kaya (misalnya rubrik multi-level dan lampiran terstruktur) tetap perlu dikonfigurasi/didesain. |
| EPA | Mapping many-to-many/KSA, skala observasi dan target berversi, observasi longitudinal, readiness, flag/notifikasi preseptor, panel assignment, quorum configurable, defer/restrict/revoke, chair, conflict/recusal, dissent, appeal per ronde, dossier snapshot, review due, pengingat terjadwal, grafik tren per versi skala, ringkasan kecukupan/keragaman, dan tabel cakupan observasi per periode rotasi tersedia. Tabel siklus memisahkan validitas, keragaman, serta flag keselamatan terbuka dan tidak menyamakan skala. | Interpretasi target dan ambang perubahan antar-siklus belum dikonfigurasi sebagai kebijakan; governance komite lintas institusi dan expiry tetap memerlukan keputusan program. |
| Capaian | Usulan/keputusan dipisah; snapshot framework/evidence dan review final immutable tersedia. | Kebijakan level capaian dan proses reconsideration/appeal belum disepakati. |
| Integrasi | Identity mapping/reconciliation, adapter payload Moodle/Examtool/OSCE serta WPBA klinis eksternal, canonical upsert idempoten, revision audit, dan toggle integrasi tersedia. Syarat Bukti EPA eksternal hanya menerima sumber klinis; seluruh hasil impor tetap belum tervalidasi. | Belum ada konektor jaringan live ataupun pemetaan file vendor-specific tanpa API/format aktual. |
| Role/access | Devise tetap; role lama dijaga; assignment memuat scope dan masa berlaku; revoke mencatat aktor/waktu. EPA panel/dossier/safety, WPBA, artefak, keputusan capaian, kasus dan logbook memerlukan relasi tugas yang tercatat; admin teknis tidak memperoleh akses klinis otomatis. Dashboard analitik mengecek role akademik; ekspor membatasi prodi untuk Kaprodi; lampiran memeriksa policy record; proyek akhir memisahkan akun admin teknis dari penilaian; dan pencarian admin mengarah ke pengelolaan akun. | Belum ada matriks kewenangan Tenaga Kependidikan yang mencakup setiap field non-klinis; fitur akademik legacy di luar Core masih perlu review produk dan assignment per fungsi. |
| Peta Artefak | Submission, review append-only, provenance source, Portofolio Terpilih, dan visibility privat/assigned-reviewer tersedia. | Publikasi eksternal, retention, serta snapshot isi ketika source dikoreksi membutuhkan kebijakan produk. |

### Di luar ruang lingkup JEJAK

Jangan mengembangkan LMS, kursus/konten, presensi dan penjadwalan kelas, bank soal/engine CBT, atau engine pelaksanaan OSCE. SIA tetap menangani administrasi akademik lengkap. JEJAK menyimpan konteks akademik minimum dan bukti relevan saja.

## Batas domain modular yang disarankan

Tetap satu aplikasi Rails/PostgreSQL modular monolith; batas domain bukan Rails Engines atau microservices.

| Domain | Status | Tanggung jawab |
|---|---|---|
| Core E-Portfolio | wajib | Framework, blueprint, Expected Evidence, canonical evidence, refleksi/feedback, kurasi artefak, Portofolio Terpilih, kecukupan, attainment dan dashboard. |
| Logbook Klinis | opsional | Aktivitas profesional, peran, kompleksitas, supervisi, konteks minimal, validasi aktivitas; sumber bukti, bukan keputusan kompetensi. |
| WPBA | opsional | Mini-CEX, CEC, CWS, BPE, DOPS, CbD, dan MSF berversi; hasil final dikirim ke Core. EPA Observation bukan instrumen WPBA. Tidak punya portofolio terpisah. |
| EPA | kontekstual/opsional | Unit kerja profesional, target supervisi, observasi longitudinal, dossier, promosi, keputusan ad hoc dan keputusan panel. Tidak sama dengan WPBA. Dapat diaktifkan pada seluruh jenjang, tetapi tidak wajib bagi program studi. |
| Integration Layer | adapter opt-in independen | SIA, Moodle, Examtool, OSCE, dan WPBA klinis eksternal hanya komunikasi/transformasi payload kanonik; Core berjalan tanpa adapter. |
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

ERD ini konseptual; tabel yang sudah nyata antara lain EvidenceSource/EvidenceRecord, ArtifactSubmission/PortfolioSelection, EvidenceRequirementVersion, EpaPromotion/EpaPromotionReview, UserAssignment, serta tabel framework dan blueprint. SufficiencyEvaluation dan PromotionDossier adalah agregat/snapshot layanan, bukan nama tabel yang diklaim tersedia.

## Canonical Evidence dan kontrak lintas modul

| Bagian | Elemen kanonik |
|---|---|
| Provenance | source system, source record ID/revision, stable source activity ID, internal learner ID, waktu impor/sinkronisasi, reference/hash payload jika perlu. Upsert idempotent. |
| Akademik | program, periode/semester/kelas/rotasi bila tersedia, status saat peristiwa, otoritas sumber per atribut. |
| Asesmen | jenis/instrumen dan versi, event, waktu, skala dan skor/kategori, finalisasi/revisi, penilai, feedback dan validation state/actor/time. |
| Konteks | aktivitas/kasus, kompleksitas, peran, supervisi, lokasi/rotasi dengan minimisasi data klinis. Identitas pasien tidak masuk portofolio. |
| Pemetaan | kompetensi/indikator/EPA dan framework version, sumber/versi mapping, masa berlaku dan status verifikasi. |
| Artefak/privacy | reference ke sumber, versi, visibility dan consent; privat default, publikasi memerlukan izin terpisah. |

EvidenceSource menjadi registri bukti kanonis untuk asal lokal/WPBA/eksternal, provenance, validasi, activity key, dan revisi. EvidenceRecord mempertahankan relasi legacy sambil memakai EvidenceSource untuk ingest kanonis; konsolidasi jalur koreksi lintas semua sumber masih tersisa.

Kontrak:

- Logbook mengirim referensi dan ActivityValidated; Core tetap menilai EvidenceValidated.
- WPBA mengirim AssessmentFinalized dengan instrumen/version, skala, konteks, penilai, feedback dan revisi.
- EPA observation adalah satu sumber bukti; promosi/review/decision bukan observasi tambahan.
- Adapter eksternal mengirim normalized payload dengan status trusted atau needs_validation dan upsert idempotent.
- Core menghitung sufficiency saja; tidak membuat attainment otomatis.
- Semua domain meminta authorization dan assignment scope dari layanan bersama.

Evidence rule perlu versi, operator (semua/alternatif/kombinasi), sumber, minimum, kualitas/hasil, keragaman kasus/penilai/waktu/kesempatan, rentang waktu, critical/safety dan independence scope. Satu aktivitas boleh mendukung beberapa kompetensi tetapi tidak menjadi beberapa kesempatan independen dalam independence group yang sama. Perubahan rule membuat evaluasi versi baru, bukan menulis ulang histori.

## Integrasi opsional dan data akademik

Importer CBT/OSCE dan Glide yang ada tetap berjalan berdampingan dengan adapter payload kanonis, termasuk impor WPBA klinis eksternal untuk Syarat Bukti EPA ketika diaktifkan. Staging vendor-spesifik belum dapat difinalisasi sampai contoh file/API dan aturan pencocokan dari institusi tersedia.

| Sumber | Data relevan | Strategi |
|---|---|---|
| SIA | identitas, prodi/jenjang, periode, kelas/member, status mahasiswa/dosen | Manual tetap tersedia; CSV/XLSX staging dengan preview, reconciliation dan error report; API bila disetujui. Otoritas sumber per atribut. |
| Moodle | referensi tugas/artefak pilihan, hasil final, feedback/refleksi pilihan | API/webhook bila ada; file fallback. Tidak menyinkronkan konten, jadwal atau presensi. |
| Examtool | exam ID, hasil, skor/kategori, domain bila ada, finalization/revision | API/webhook atau staging CSV/XLSX. Tidak mengelola bank soal. |
| OSCE | exam/station ID, hasil per peserta/station/domain, feedback/finalization | API/pertukaran file dan mapping versi framework. Tidak melaksanakan station. |

Mode manual, impor dan integrasi SIA bisa dikombinasikan per data. JEJAK memakai ID internal stabil; external ID dipetakan dengan issuer, bukan nama. Tidak ada FK wajib ke sistem luar. Perubahan status akademik tidak menghapus bukti historis.

## Logbook, artefak, refleksi dan portofolio

Alur target: Catatan Logbook → Validasi Aktivitas → Kandidat Artefak mahasiswa (alasan pemilihan/refleksi opsional) → Pengajuan → Telaah relevansi, privacy dan izin tampil → Portofolio Terpilih. Evidence dapat memenuhi requirement walau tidak dipilih tampil. Simpan reference ke logbook/version, bukan salinan seluruh isi. Portfolio privat default; persetujuan akademik bukan izin publikasi.

Empat keputusan tetap berbeda: validasi aktivitas, validasi bukti, persetujuan tampil sebagai artefak, dan keputusan capaian. ActivityLog memiliki verifier; kandidat artefak, telaah, dan Portofolio Terpilih sudah tersedia dengan referensi sumber dan status privat.

Ganti menu Pengalaman Belajar dengan Refleksi Pengalaman Belajar. Prompt: Apa yang saya alami? Apa yang saya pelajari? Apa yang masih perlu saya perbaiki? Apa yang akan saya lakukan selanjutnya? Refleksi tidak otomatis wajib di setiap kegiatan; Expected Evidence dapat mewajibkannya. Hubungkan opsional ke kompetensi, artefak, logbook, asesmen, WPBA/EPA, feedback dan tindak lanjut.

## WPBA

MiniCexEvaluation dan DopsEvaluation tetap menyimpan dimensi/skor instrumen masing-masing. Katalog WPBA dan versi instrumen terbit immutable mendukung komponen dinamis instrumen tambahan tanpa mengubah skala historis; observasi tambahannya disimpan pada WpbaObservation. Skala instrumen berbeda tidak disamakan hanya karena ordinal.

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

1. EPA sudah memiliki katalog, pemetaan many-to-many, KSA, ruang lingkup, batas kewenangan, target jenjang dan skala berversi. Perlu audit kelengkapan data katalog dan alur pembaruan definisi.
2. KSA satu dimensi per mapping; perlu keputusan apakah satu atau beberapa dimensi/kriteria.
3. Target lintas jenjang dan versioning tersedia; mekanisme perpanjangan/masa berlaku entrustment belum lengkap.
4. Chen/Ottawa harus mempertahankan definisi/anchor masing-masing; ordinal bukan konversi otomatis.
5. EpaObservation bukan WPBA generik dan tidak langsung mereferensikan AssessmentEvent/BlueprintItem/instrumen.
6. Status/koreksi/return/void perlu transisi permission dan audit.
7. Belum ada dossier longitudinal lengkap untuk variasi kasus/penilai/waktu, trend, safety dan gap.
8. Anggota panel, Ketua Panel, dan quorum eksplisit per assignment/program. Conflict otomatis recusal; dissent tersimpan sebagai rekomendasi berbeda dan Ketua Panel mengesahkan setelah quorum.
9. Defer, needs-more-evidence, restricted scope, revoke, appeal per ronde, serta review due tersedia. `EpaEntrustmentReviewDueJob` mengirim notifikasi harian sekali kepada mahasiswa, pengambil keputusan, preseptor rotasi aktif, dan panel yang ditugaskan; renewal tetap dimulai manual setelah tanggal review jatuh tempo. Tata kelola komite lintas institusi belum tersedia.
10. EntrustmentDecision masih memiliki LEVELS 1–5/compatibility mapping; bukan definisi Chen/Ottawa.
11. Assignment pusat mengatur panel, Ketua Panel, reviewer, preseptor/evaluator, pemvalidasi, dan pengusul/pengambil keputusan. Quorum configurable adalah aturan aplikasi, bukan pengganti kebijakan institusi.
12. Daftar observasi EPA sudah menampilkan tren supervisi menurut versi skala dan ringkasan kecukupan/variasi bukti. Analisis lintas ronde dan perbandingan target supervisi per EPA masih perlu ditingkatkan; grafik ordinal tidak boleh mencampur versi atau jenis skala.

State machine desain:

- Observasi formatif: draft → submitted → recorded; submitted → returned → resubmitted; recorded hanya dikoreksi/dibatalkan melalui event revisi beralasan. Safety triage terpisah dari rating.
- Dossier: not_ready → eligible_flagged → preceptor_review → promoted_to_authority → panel_review → deferred/needs_evidence | not_entrusted | entrusted_with_scope | entrusted | restricted → review_due → renewed/restricted/revoked.
- Eligibility bukan keputusan. Preseptor meninjau/endorses atau menahan dengan alasan. Panel memeriksa dossier snapshot dan dissent. Hanya final authority mengesahkan. Rata-rata skor tidak menentukan keputusan.

Flag promosi-preseptor tersedia. Panel mendapat dossier snapshot; recusal, dissent, keberatan, pengesahan Ketua Panel, dan review due terpisah dari observasi. Pekerjaan tersisa berfokus pada pengingat jatuh tempo dan analitik longitudinal, tanpa menyamakan kesiapan dengan izin praktik.

## Role, permission dan assignment

User memakai Devise dan Role/UserRole dengan active_role. Role lama tetap: admin, kaprodi, dosen, preseptor, mahasiswa; `tenaga_kependidikan` sudah menjadi role seed. Role = kapasitas; permission = aksi; assignment = objek/lingkup dan masa berlaku. Area sensitif menerapkan default deny, server-side scope, dan audit grant/revoke. Admin teknis tidak otomatis memperoleh akses dossier atau keputusan akademik.

| Role | Akses yang disarankan |
|---|---|
| Mahasiswa | Data sendiri: target kompetensi, koleksi, refleksi, artifact submission, feedback, sufficiency, attainment dan EPA yang relevan; tidak mengesahkan bukti sendiri. |
| Preseptor | Learner/rotasi assigned: validasi logbook, WPBA/EPA observation, feedback dan kesiapan promosi; bukan keputusan final default. |
| Dosen | Cohort/mahasiswa assigned: feedback, evidence review, WPBA/panel sesuai assignment. |
| Kaprodi | Peta/blueprint program dan analitik; keputusan/panel hanya dengan appointment. |
| Tenaga Kependidikan | Rekonsiliasi roster/import/data minimum bila ditugaskan; tanpa narasi klinis/refleksi/keputusan secara default. |
| Administrator | Konfigurasi teknis, identitas, integrasi/import/log; bukan panel akademik otomatis. Akses konten klinis perlu assignment atau break-glass. |

Policy Pundit yang ada menjadi titik penerapan. Policy kasus, logbook, EPA, WPBA, artefak dan capaian yang disentuh menggunakan scope/assignment server-side. Audit endpoint lain tetap perlu diteruskan; penyembunyian menu bukan otorisasi.

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

Audit akses legacy menemukan `FinalProjectPolicy` sebelumnya menggunakan `User#instructor?` yang juga mencakup admin, sehingga akun admin teknis dapat melihat dan memberi skor ke seluruh tugas akhir. Kebijakan kini membatasi akses menyeluruh/pemberian skor ke dosen/preseptor; admin teknis hanya dapat melihat proyek miliknya atau yang tercatat sebagai pembimbing. Route dan data proyek dipertahankan karena belum ada persetujuan penghapusan.

Audit WPBA menemukan pemeriksaan assignment built-in memanggil kembali dirinya sendiri untuk assignment eksplisit, dan rotasi menerima admin teknis sebagai preseptor. Pemeriksaan kini memisahkan kapasitas dosen/preseptor bawaan dari assignment WPBA eksplisit, memutus rekursi tersebut, dan menolak role admin saja sebagai preseptor. Audit EPA lanjutan juga menemukan `User#instructor?` memasukkan admin teknis ke pemeriksaan pengamat. Pembuatan observasi kini memerlukan preseptor/dosen yang terkait dengan kasus/rotasi atau assignment `epa_observer`; pembacaan dossier juga mengizinkan anggota panel yang ditugaskan. Regresi menutup akses admin teknis melalui relasi preseptor historis dan menguji pengamat yang ditugaskan langsung.

Pemeriksaan akses profil menemukan bahwa pengguna biasa dapat mengubah `study_program_id` miliknya sendiri, yang berpotensi memindahkan akun ke lingkup program studi lain dan melewati batas akses. Pembaruan afiliasi kini hanya diizinkan bagi administrator; formulir staf/mahasiswa menampilkan afiliasi sebagai informasi baca-saja. Pemeriksaan halaman nilai dan asesmen juga menemukan admin teknis tanpa peran akademik dapat membuka beberapa ringkasan mahasiswa melalui `student_id`. Halaman terkait kini mensyaratkan penilai/kaprodi berlingkup sama dan detail asesmen menjalankan policy record secara eksplisit.

Audit lanjutan menemukan dua jalur yang belum tertutup oleh regresi sebelumnya: admin teknis saja dapat melewati gerbang umum `can_view_students?` pada dashboard/pencarian dan dapat terhitung sebagai pengusul capaian melalui helper `instructor?`. Hak direktori admin kini dipisahkan dari akses akademik; dashboard mahasiswa memerlukan peran akademik, admin tetap dapat mencari akun tetapi kartu menuju halaman administrasi, dan admin hanya menjadi pengusul bila menerima assignment eksplisit. Daftar Syarat Bukti Kaprodi dibatasi ke framework/blueprint programnya sendiri. Audit berikutnya membatasi pembacaan, pilihan subjek, dan ekspor jawaban Assessment Form Kaprodi ke kiriman yang terkait dengan programnya; akun tanpa program masih dapat menjadi subjek karena afiliasi akademiknya belum terdata, sedangkan admin tetap memiliki cakupan audit global.

Role Tenaga Kependidikan sebelumnya telah ada di seed, tetapi belum memiliki menu atau assignment operasional. Kini administrator/Kaprodi dapat menunjuk `external_data_manager` pada satu program studi; hanya staf ber-role `tenaga_kependidikan` yang dapat menerima tugas ini. Assignment tersebut membuka impor bukti dan pemetaan identifier hanya untuk program yang ditetapkan. Otorisasi controller dan resolver mapping memeriksa ulang lingkup, sementara navigasi desktop/mobile hanya menampilkan dua tautan integrasi saat assignment aktif. Role ini tidak memperoleh izin klinis/WPBA atau kewenangan akademik. Tes juga menemukan dan menutup query PostgreSQL yang membawa `ORDER BY` ke subquery `DISTINCT` pada daftar pemetaan.

Impor bukti eksternal kini memiliki antrean telaah terpisah: status impor tetap `unverified` sampai dosen, preseptor, atau Kaprodi menerima assignment `evidence_reviewer` yang lingkupnya sesuai. Reviewer tidak dapat menyetujui batch yang diimpornya sendiri; validasi/penolakan bersifat satu arah, penolakan memerlukan alasan, dan payload sumber/provenance tidak dapat ditulis ulang. Batch serta pengimpor dicatat pada metadata internal yang tidak dapat disuplai atau ditimpa oleh metadata vendor. Menu antrean mengikuti assignment di navigasi desktop/mobile; pengguna tanpa assignment ditolak di server.

Audit Form Builder menemukan template global dapat diedit Kaprodi mana pun karena belum memiliki pemilik program. Migration `20261122170003` menambah scope program opsional, mempertahankan template institusi dan menautkan template lama yang dibuat Kaprodi ke programnya. Admin dapat membuat template institusi atau memilih program; Kaprodi hanya membuat/mengelola template programnya, dapat membaca template institusi, dan tidak dapat membuka template program lain. Pemetaan kompetensi template program juga dibatasi ke framework milik program tersebut. Migration diuji pada database test dalam satu transaksi; tidak memakai concurrent index atau `disable_ddl_transaction!`.

Sidebar sekarang mengikuti empat tahap OBE dan menu administrasi hanya menawarkan route yang tersedia untuk role aktif. Menu Pengalaman Belajar sebagai aktivitas mandiri dan tautan jadwal/ujian internal dihapus dari navigasi; refleksi, WPBA, Logbook, promosi EPA, kurasi artefak, serta konfigurasi hanya muncul sesuai role, assignment, jenjang, status modul, dan riwayat. Mahasiswa hanya dapat memilih Peta Kompetensi/Peta Artefak program studinya; akses Peta Artefak dibatasi server-side.

Guard aktivasi WPBA kini memakai program studi mahasiswa pada rotasi sasaran, bukan afiliasi penilai. Form DOPS, Mini-CEX, dan instrumen observasi khusus hanya menawarkan rotasi yang modul WPBA-nya aktif; direct URL untuk input maupun koreksi riwayat juga memeriksa status program sasaran. Ini mendukung penilai yang mendapat assignment lintas program dan tetap mempertahankan pembacaan observasi historis saat modul dimatikan.

Dasbor mahasiswa kini merangkum kecukupan Syarat Bukti lintas siklus berdasarkan tanggal bukti dan periode akademik. Siklus hanya menilai konfigurasi Syarat Bukti yang sudah ada pada akhir periode tersebut; bukti terpilih dihitung menurut versi yang berlaku bagi mahasiswa. Ringkasan melaporkan jumlah terpenuhi, berjalan, belum dimulai, serta syarat wajib/kritis yang tersisa dan tidak membuat keputusan capaian.

Peta EPA mengikuti aktivasi modul dan assignment: dapat digunakan pada Sarjana maupun jenjang lain jika diaktifkan, sedangkan program yang menonaktifkan EPA mempertahankan riwayat baca sesuai izin. Keputusan ad hoc memakai skala supervisi prospektif berversi dan terpisah dari dossier panel; lifecycle keputusan mencatat event audit.

Rubrik instrumen WPBA khusus kini dapat menyimpan jangkar label dan deskripsi untuk setiap nilai ordinal dalam rentang rating. Form observasi memakai pilihan bertingkat berjangkar; detail observasi menampilkan label, deskripsi, dan ordinal asli. Definisi versi tetap immutable setelah diterbitkan, sehingga perubahan rubric hanya berlaku pada versi baru dan tidak mengubah makna observasi lama.

Bilah mobile dan breadcrumb diperbarui agar sesuai dengan tahap/role yang sama. “Analisis Kesenjangan”, “Evaluasi Asesmen”, “Evaluasi Pembelajaran”, dan “Tindak Lanjut” belum memiliki halaman mandiri yang dapat ditautkan; dashboard analitik tetap satu-satunya menu evaluasi capaian. SRQ ditampilkan sebagai layanan mahasiswa terpisah dari alur OBE. Label navigasi kini memakai terminologi yang dapat dikonfigurasi; menu relabel program studi ditautkan untuk admin dan kaprodi. Framework terpilih pada program studi menjadi sumber Peta Kompetensi; tanpa mahasiswa tidak ada fallback lintas program.

## Pekerjaan tersisa dan titik kode aktual

| Area | Titik aktual | Arah |
|---|---|---|
| Core/framework | competency_framework.rb, competency_item.rb, competency_indicator.rb, competency_framework_duplicator.rb, schema.rb | konsistensi clone/version dan historical reference. |
| Blueprint/evidence | assessment_blueprint.rb, blueprint_version.rb, blueprint_item.rb, evidence_requirement.rb, evidence_record.rb, evidence_requirement_progress.rb | canonical provenance, rule version, sufficiency snapshot; jaga mapping lama. |
| WPBA | mini_cex_evaluation.rb, dops_evaluation.rb, `wpba_observation.rb`, WpbaInstrument/Version, controllers/forms/routes/policies, migrations `20261122160001`–`20261122160002` dan `20261122170001`–`20261122170002` | instrumen khusus berversi dengan komponen dinamis, observasi tambahan, correction lineage, link EvidenceRecord kanonis dan assignment; implementasi rubrik/attachment lebih kaya dapat ditambah setelah desain disetujui. |
| Logbook/portfolio/reflection | activity_log.rb, reflection_entry.rb, portfolios_controller.rb serta routes/views | candidate/review/selection/privacy dan prompt refleksi. |
| EPA | model EPA di atas, controllers/services/views/routes dan migration `20261122100001`–`20261122130003`, `epa_cycle_evidence_summary.rb` | katalog progres, pengingat, workflow renewal manual, grafik per versi skala, dan cakupan/keragaman observasi per periode rotasi tersedia; interpretasi tren terhadap target lintas siklus dan expiry otomatis menunggu kebijakan program. |
| Access | user.rb, role.rb, user_role.rb, user_assignment.rb, clinical_rotation.rb, clinical_case.rb, app/policies/* | permission/assignment granular termasuk assignment data eksternal Tendik; Devise dan role lama dipertahankan. |
| Integrasi | `external_evidence_imports` route, ExternalEvidenceImportsController, ExternalEvidenceCsvImport, ExternalEvidenceSpreadsheet, ExternalEvidenceAdapter, `ClinicalWpbaAdapter`, CanonicalEvidenceIngestor, ExternalIdentityMapping, ExternalImportBatch, migration `20261122120001` | CSV/XLSX Moodle/Examtool/OSCE/WPBA klinis eksternal dua tahap, preview/hash file asli, audit batch, transaksi atomik dan canonical evidence idempoten; EPA menolak sumber non-klinis dan bukti impor tetap perlu validasi. Transport API serta pemetaan vendor tetap opsional. |
| Akses WPBA/legacy | ClinicalRotation, AssessmentAssignment, AssignmentAuthorization, DopsEvaluationPolicy, MiniCexEvaluationPolicy, FinalProjectPolicy | preseptor bawaan harus memiliki role akademik; assignment WPBA eksplisit didukung terpisah; admin teknis tanpa assignment tidak dapat membuka/menilai WPBA atau proyek akhir. |
| Navigasi | navigation_helper.rb, shared sidebar/mobile views, config/routes.rb, navigation tests | capability-based menu; URL tetap terlindungi. |

Migration terbaru telah dibuat dan diuji pada database test lokal. Tidak ada migration production.

## Rencana penyelesaian tersisa

1. Lanjutkan audit permission pada route legacy dan lengkapi matriks baca/ubah per role; jalur integrasi Tendik kini dibatasi oleh assignment program studi.
2. Kontrak staging kini menerima CSV dan XLSX kanonik; validasi skema vendor-spesifik dan rekonsiliasi koreksi tetap memerlukan sampel dari institusi. Konektor jaringan tetap opsional.
3. Konfigurasikan kebijakan expiry/masa berlaku entrustment per program jika disetujui; workflow renewal dan reminder due review sudah tersedia.
4. Lengkapi tindak lanjut EPA dan tentukan interpretasi target lintas siklus; dashboard sekarang membandingkan kecukupan bukti per periode akademik, sedangkan tren supervisi per versi skala ditampilkan di dossier.
5. Pertimbangkan attachment observasi WPBA hanya jika pemilik produk menetapkan kebutuhan, retensi, sanitasi data klinis, dan kebijakan aksesnya; versi sekarang mendukung rating berjangkar, text, select, dan boolean, dengan koreksi yang mempertahankan histori dan kesempatan bukti.
6. Jalankan security/direct-route matrix tambahan, migration dari baseline bersih, dan smoke-test alur mahasiswa-preseptor-panel.

Evidence contract/assignment menjadi fondasi WPBA/EPA; kuorum, komposisi, masa tinjauan, dan keputusan final tetap harus disetel sesuai SOP institusi.

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

Core, Logbook, WPBA, kurasi portofolio, provenance/versioning, kontrak evidence, impor bukti CSV/XLSX dua tahap untuk payload Moodle/Examtool/OSCE, pemisahan validasi aktivitas/bukti/sufficiency/keputusan, assignment bersama, workflow CCC EPA dengan Ketua Panel/recusal/appeal, pengingat review terjadwal, renewal melalui dossier baru yang mempertahankan keputusan lama sampai keputusan panel baru disahkan, progres seluruh EPA terbit, grafik supervisi longitudinal per versi skala, dan ringkasan observasi EPA lintas periode rotasi telah tersedia pada working tree. Sisa terbesar adalah konektor jaringan dan pemetaan format vendor spesifik, kebijakan expiry/interpretasi target lintas siklus, serta audit akses fitur legacy di luar Core.

Suite penuh terakhir: **828 runs, 4.829 assertions, 0 failures, 0 errors, 0 skips. Suite modul/adapter EPA terfokus: 42 runs, 247 assertions, 0 failures, 0 errors, 0 skips; uji impor WPBA eksternal: 7 runs, 47 assertions, 0 failures, 0 errors, 0 skips**. `zeitwerk:check` dan `git diff --check` lulus setelah perubahan koreksi WPBA dan assignment Tendik. Halaman progres kini menampilkan semua EPA aktif framework terbit, meski belum ada promosi/Syarat Bukti, dan membedakan kecukupan dari keputusan panel. Grafik supervisi menggunakan observasi yang layak dihitung dan memisahkan setiap skala beserta versinya; flag keselamatan yang belum ditinjau tidak masuk grafik. Pengingat EPA mengirim satu notifikasi per penerima (mahasiswa, pengambil keputusan, preseptor aktif dan panel yang ditugaskan), lalu menandai keputusan agar pemanggilan berulang tidak menduplikasi; cakupannya diuji untuk due dan superseded. Renewal membuat dossier terpisah yang merujuk keputusan lama; keputusan aktif tidak berubah selama review dan baru disupersede setelah finalisasi. Impor CSV/XLSX membatasi scope ke prodi, menolak baris tidak valid, memeriksa ulang hash berkas asli saat konfirmasi, melakukan seluruh ingest dan finalisasi batch dalam satu transaksi, serta menolak pengubahan/penghapusan riwayat final. XLSX membaca sheet pertama, memetakan tanggal bertipe Excel, serta membatasi ukuran arsip dan baris/kolom. Suite juga menguji afiliasi program studi yang tak dapat diubah sendiri, akses admin teknis tanpa assignment terhadap asesmen, pembatasan akses WPBA/EPA/proyek akhir, jalur impor/pemetaan Tendik hanya dalam program penugasan, koreksi WPBA tanpa mengubah histori dan propagasi Syarat Bukti sebagai satu kesempatan, penautan CBD terhadap Syarat Bukti WPBA, penunjukan pengamat EPA granular, instrumen WPBA khusus dinamis, form observasi, policy assignment, tautan observasi khusus sebagai satu sumber bukti, dan navigasi riwayat saat modul input WPBA dimatikan.

Pembaruan verifikasi 22 November 2026: suite penuh terbaru lulus **845 runs, 4.938 assertions, 0 failures, 0 errors, 0 skips**. Regresi tambahan meliputi aktivasi WPBA berdasarkan program mahasiswa untuk penilai lintas program, penolakan input/koreksi saat program sasaran menonaktifkan WPBA, penyaringan rotasi pada formulir baru, rubric WPBA dengan jangkar deskriptif per level, pembatasan tautan dan direct route EPA untuk Sarjana, ringkasan kecukupan bukti per siklus tanpa penerapan retroaktif, isolasi scope Form Builder lintas program, serta antrean validasi bukti eksternal dengan assignment, larangan self-review, provenance impor yang immutable, dan navigasi berbasis role.

Pembaruan implementasi terpadu berikutnya: suite penuh lulus **848 runs, 4.959 assertions, 0 failures, 0 errors, 0 skips**; tes terfokus EPA, refleksi, WPBA, dan navigasi lulus **101 runs, 606 assertions, 0 failures, 0 errors, 0 skips**. `zeitwerk:check` dan `git diff --check` lulus. Katalog WPBA mencakup tujuh metode, ringkasan MSF baru ditampilkan setelah tiga penilai, refleksi dapat menunjuk evidence milik mahasiswa tanpa menduplikasi record, dan keputusan ad hoc memiliki status serta event lifecycle tersendiri.

Perubahan berada di working tree dan migration hanya dijalankan pada database test lokal. Tidak ada perubahan Devise, penghapusan data, commit, push, deployment, atau migration production. Koneksi vendor dan aturan operasional CCC/renewal harus dikonfigurasi menurut lingkungan institusi sebelum diaktifkan.
