# Peran, Hak Akses, dan Assignment

JEJAK menggunakan dua gerbang terpisah untuk tindakan asesmen:

1. **RBAC** (model `Role` → `RolePermission` → `SystemPermission`) menjawab tindakan apa yang boleh dilakukan pengguna, dan pada cakupan mana. Di antarmuka, Role disebut **Peran**.
2. **Assignment** (`UserAssignment`, serta assignment klinis existing seperti preseptor pada rotasi) menjawab mahasiswa, rotasi, atau dossier mana yang boleh ditangani.

Untuk menilai mahasiswa, pengguna harus memiliki hak akses asesmen yang sesuai **dan** assignment aktif yang mencakup mahasiswa/kegiatan tersebut. Peran atau hak akses saja tidak menjadikan pengguna penilai untuk semua mahasiswa; assignment saja juga tidak memberikan hak untuk bertindak.

## Cakupan peran

- `system`: pemberian peran berlaku sebagai identitas sistem. Batas hak akses tetap ditentukan oleh cakupan setiap `RolePermission`.
- `study_program`: pemberian peran hanya berlaku pada program studi yang direferensikan oleh `user_roles.study_program_id`.
- `unassigned`: hanya untuk mempertahankan peran admin lama yang belum memiliki program studi. Pemberian ini tidak memberikan hak admin sampai ditetapkan ulang.

Hak akses `study_program` pada peran global hanya berlaku pada program studi profil pengguna. Hak akses `system` pada peran global dapat berlaku lintas program. Jika pemberian peran dibatasi ke satu program studi, hak akses tetap dibatasi ke program itu.

Peran admin program studi bukan superadmin. Akses superadmin tidak diberikan otomatis kepada akun lama atau akun tanpa program studi.

## Bootstrap superadmin

Setelah database dan akun operator tersedia, berikan akses sistem secara eksplisit:

```sh
bin/rails 'rbac:bootstrap_superadmin[operator@example.org]'
```

Perintah ini memberikan peran `superadmin` dan `admin` dengan cakupan sistem kepada akun tersebut. Jangan menjalankannya pada akun yang tidak disetujui sebagai administrator teknis institusi. Superadmin pertama sebaiknya ditetapkan oleh operator instalasi, bukan melalui pendaftaran publik.

Peran bawaan tidak dapat dihapus. Peran kustom yang masih diberikan kepada pengguna harus dicabut dari penetapan pengguna sebelum dihapus. Perubahan RBAC tidak mengubah assignment penilai yang sudah ada.

## Inisialisasi permission

Migration membuat katalog hak akses. `db:seed` menyiapkan hak akses bawaan setiap peran secara idempotent. Superadmin dapat menyesuaikan hak akses peran dari menu **Kelola Peran & Hak Akses**; peran dan hak akses tidak menetapkan reviewer, preseptor, atau anggota panel tertentu.
