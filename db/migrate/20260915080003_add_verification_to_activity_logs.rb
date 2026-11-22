# Penanda terverifikasi untuk Logbook Kegiatan (Paket Dasar M02: "Kalender
# kegiatan berpenanda verifikasi"). Sebelum migrasi ini ActivityLog sama
# sekali tanpa mekanisme verifikasi — beda dari ClinicalCase yang sudah
# punya alurnya sejak Fase 5. Kolom baru nullable; indeks/FK tetap dalam
# transaksi, dan FK divalidasi oleh migration lanjutan.
class AddVerificationToActivityLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :activity_logs, :verified_at, :datetime
    safety_assured do
      add_reference :activity_logs, :verified_by, index: true
      add_foreign_key :activity_logs, :users, column: :verified_by_id, validate: false
    end
  end
end
