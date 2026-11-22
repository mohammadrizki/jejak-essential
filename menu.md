Betul. **Navigasi berbasis role harus menjadi bagian dari rancangan arsitektur JEJAK**, bukan sekadar penataan sidebar setelah seluruh modul selesai.

Saya menyarankan enam role menggunakan **modul yang sama, tetapi dengan menu, tindakan, dan cakupan data yang berbeda**. Dengan demikian, kita tidak membuat enam aplikasi terpisah.

## **1. Rancangan navigasi untuk enam role**

## **Pratinjau navigasi JEJAK**

Pilih role untuk melihat struktur menu yang diusulkan.

Administrator

Kaprodi

Dosen

Preseptor

Mahasiswa

Tenaga Kependidikan

## **Administrator**

Mengelola konfigurasi dan operasional sistem, bukan mengambil keputusan akademik.

Dashboard Sistem

- Status modul

- Status integrasi

- Kesehatan sinkronisasi

Manajemen Institusi

- Institusi & Program Studi

- Pengguna & Identitas

- Sumber Data Akademik

Akses & Kewenangan

- Role & Permission

- Assignment

- Audit Akses

Konfigurasi Sistem

- Aktivasi Modul

- Integrasi Eksternal

- Pengaturan Sistem

Dashboard Program Studi
- Capaian Kompetensi
- Kesenjangan Bukti
- Status Asesmen

Perumusan Capaian
- Pustaka Kerangka Kompetensi
- Peta Kompetensi
- Blueprint Asesmen
- Syarat Bukti
- Peta Artefak

Pengelolaan Portofolio
- Portofolio Mahasiswa
- Refleksi & Umpan Balik
- Monitoring Logbook
- Monitoring WPBA

Asesmen & Keputusan
- Kecukupan Bukti
- Review Capaian Kompetensi
- EPA & Entrustment

Evaluasi & Peningkatan Mutu
- Analisis Kesenjangan
- Evaluasi Bukti & Asesmen
- Tindak Lanjut

Dashboard Dosen
- Mahasiswa Bimbingan
- Tugas Review
- Umpan Balik Tertunda

Portofolio Mahasiswa
- Koleksi Bukti
- Refleksi Pengalaman Belajar
- Portofolio Terpilih

Review & Asesmen
- Telaah Artefak
- Penilaian Bukti
- Hasil Asesmen
- Review Kecukupan Bukti

Bimbingan
- Umpan Balik
- Rencana Tindak Lanjut
- Perkembangan Kompetensi

Dashboard Preseptor
- Mahasiswa Supervisi
- Validasi Tertunda
- Observasi Tertunda

Logbook Klinis
- Validasi Kasus
- Validasi Tindakan
- Riwayat Logbook

Workplace-Based Assessment
- Mini-CEX
- DOPS
- CBD
- Instrumen Lain

EPA
- Observasi EPA
- Progres Supervisi
- Rekomendasi Entrustment

Umpan Balik
- Umpan Balik Klinis
- Tindak Lanjut Mahasiswa

Dashboard Saya
- Ringkasan Capaian
- Kesenjangan Bukti
- Tindak Lanjut

Target Kompetensi
- Peta Kompetensi Saya
- Peta Artefak Saya
- Syarat Bukti

Portofolio Saya
- Koleksi Bukti
- Refleksi Pengalaman Belajar
- Pengajuan Artefak
- Portofolio Terpilih
- Umpan Balik

Logbook Klinis
- Catatan Kasus
- Catatan Tindakan
- Status Validasi

WPBA & EPA
- Hasil WPBA
- Permintaan Observasi
- Progres EPA

Capaian Saya
- Kecukupan Bukti
- Capaian Kompetensi
- Keputusan Entrustment

Dashboard Operasional
- Antrian Administratif
- Data Belum Lengkap
- Status Sinkronisasi

Data Pendukung
- Data Mahasiswa
- Data Dosen & Preseptor
- Konteks Akademik

Administrasi Portofolio
- Kelengkapan Dokumen
- Status Pengajuan
- Penugasan Reviewer

Dukungan Asesmen
- Administrasi WPBA
- Administrasi Komite EPA
- Laporan Operasional

## **2. Aturan navigasi yang harus diterapkan**

Ada empat lapisan yang menentukan apakah menu boleh muncul.

**Role**

Pengguna sedang bertindak sebagai siapa?

**Permission**

Tindakan apa yang diizinkan?

**Assignment**

Terhadap mahasiswa atau program studi mana?

**Module & Feature**

Apakah modul aktif dan fitur sudah tersedia?

**Menu dan aksi yang tersedia**

Secara teknis, menu sebaiknya dibangun dari satu konfigurasi navigasi terpusat, bukan dari kondisi `if current_user.admin?` yang tersebar di banyak view.

Satu pengguna juga dapat memiliki beberapa role. Saat berganti role aktif, navigasi dan cakupan data harus ikut berubah, tanpa menghilangkan identitas atau riwayat pengguna.

## **3. Tambahan instruksi untuk Codex**

Instruksi berikut dapat ditempelkan setelah *Master Instruction* sebelumnya.

# ADDENDUM — Navigasi Berbasis Role JEJAK Essential

Tambahkan desain navigasi untuk enam role bawaan:

1. Administrator (`admin`)
2. Kaprodi (`kaprodi`)
3. Dosen (`dosen`)
4. Preseptor (`preseptor`)
5. Mahasiswa (`mahasiswa`)
6. Tenaga Kependidikan (`tenaga_kependidikan`)

## Prinsip

Navigasi harus mengikuti tanggung jawab pengguna dalam sistem e-portfolio.

Jangan membuat enam sistem atau modul terpisah berdasarkan role.

Gunakan modul yang sama dengan akses dan tindakan berbeda.

Penentuan visibilitas dan akses harus mempertimbangkan:

- Role aktif.
- Permission.
- Assignment dan lingkup kewenangan.
- Aktivasi modul.
- Ketersediaan fitur dan route.
- Jenjang pendidikan dan konfigurasi program studi.

## Struktur menu target

### Administrator

- Dashboard Sistem
- Manajemen Institusi
- Pengguna & Identitas
- Sumber Data Akademik
- Role & Permission
- Assignment
- Aktivasi Modul
- Integrasi Eksternal
- Audit Akses
- Pengaturan Sistem

Administrator teknis tidak otomatis memiliki kewenangan melakukan penilaian atau keputusan akademik.

### Kaprodi

- Dashboard Program Studi
- Pustaka Kerangka Kompetensi
- Peta Kompetensi
- Blueprint Asesmen
- Syarat Bukti
- Peta Artefak
- Monitoring Portofolio
- Monitoring Logbook
- Monitoring WPBA
- Kecukupan Bukti
- Review Capaian Kompetensi
- EPA & Entrustment
- Evaluasi & Peningkatan Mutu

### Dosen

- Dashboard Dosen
- Mahasiswa Bimbingan
- Koleksi Bukti Mahasiswa
- Refleksi Pengalaman Belajar
- Telaah Artefak
- Penilaian Bukti
- Umpan Balik
- Review Kecukupan Bukti
- Perkembangan Kompetensi

### Preseptor

- Dashboard Preseptor
- Mahasiswa Supervisi
- Validasi Logbook
- Mini-CEX
- DOPS
- CBD
- Instrumen WPBA Lain
- Observasi EPA
- Progres Supervisi
- Umpan Balik Klinis
- Rekomendasi Entrustment

### Mahasiswa

- Dashboard Saya
- Target Kompetensi
- Peta Kompetensi Saya
- Peta Artefak Saya
- Syarat Bukti
- Koleksi Bukti
- Refleksi Pengalaman Belajar
- Pengajuan Artefak
- Portofolio Terpilih
- Logbook Klinis
- Hasil WPBA
- Permintaan Observasi
- Progres EPA
- Kecukupan Bukti
- Capaian Kompetensi

### Tenaga Kependidikan

- Dashboard Operasional
- Data Pendukung
- Kelengkapan Dokumen
- Status Pengajuan
- Administrasi Penugasan Reviewer
- Administrasi WPBA
- Administrasi Komite EPA
- Laporan Operasional

Tenaga Kependidikan tidak boleh memberikan penilaian akademik atau mengambil keputusan kompetensi kecuali secara eksplisit memperoleh kewenangan yang sah untuk tindakan tertentu.

## Persyaratan implementasi

1. Audit sidebar, routes, controllers, policies, dan role switching yang sudah ada.
2. Pertahankan kode role yang sudah digunakan.
3. Buat rancangan konfigurasi navigasi terpusat.
4. Jangan menduplikasi logika otorisasi di setiap view.
5. Pastikan akses controller dan service tetap divalidasi server-side.
6. Sembunyikan menu untuk modul yang tidak aktif.
7. Sembunyikan menu untuk fitur yang belum diimplementasikan.
8. Jangan menampilkan tautan mati atau placeholder.
9. Sediakan active state, breadcrumb, dan navigasi responsif.
10. Dukung pengguna dengan lebih dari satu role dan pergantian role aktif.
11. Pertahankan histori dan konteks akademik ketika role berubah.
12. Jangan menambahkan fitur LMS, SIA lengkap, MCQ engine, atau OSCE engine.
13. Susun matriks Role × Module × Permission × Assignment.
14. Susun struktur navigasi final untuk keenam role beserta route aktual yang tersedia.
15. Identifikasi menu yang perlu dipertahankan, diganti nama, dipindahkan, disembunyikan, atau menjadi kandidat penghapusan.

**Tahap pertama hanya audit dan rancangan. Jangan langsung melakukan refactoring destruktif, migration, commit, push, atau deployment. Tunggu persetujuan sebelum perubahan struktural.**

Satu keputusan desain yang menurut saya penting: **Kaprodi mengelola rancangan dan keputusan akademik; Dosen membimbing serta menilai bukti; Preseptor mengobservasi kinerja klinis; Mahasiswa membangun portofolionya; Tendik mendukung proses administratif; dan Administrator menjaga sistem serta kewenangan akses.**

Pemisahan ini akan membuat JEJAK tetap berorientasi pada e-portfolio, sekaligus memungkinkan Logbook, WPBA, EPA, dan integrasi eksternal berkembang tanpa membuat navigasi menjadi terlalu rumit.
