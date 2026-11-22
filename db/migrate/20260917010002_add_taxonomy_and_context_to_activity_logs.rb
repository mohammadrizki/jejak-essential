# Kolom baru Logbook Kegiatan: taksonomi 3 tingkat,
# waktu mulai/selesai, semester, rotasi klinik, dan tautan bukti & dokumen.
# Seluruh perubahan tetap dalam transaksi PostgreSQL. FK ditambahkan tanpa
# validasi di sini dan divalidasi oleh migration lanjutan.
class AddTaxonomyAndContextToActivityLogs < ActiveRecord::Migration[8.1]
  REFERENCES = {
    academic_activity_domain: :academic_activity_domains,
    academic_activity_subdomain: :academic_activity_subdomains,
    academic_activity_template: :academic_activity_templates,
    academic_period: :academic_periods,
    clinical_rotation: :clinical_rotations
  }.freeze

  def change
    add_column :activity_logs, :started_at, :datetime
    add_column :activity_logs, :ended_at, :datetime
    add_column :activity_logs, :evidence_url, :string
    add_column :activity_logs, :document_url, :string

    REFERENCES.each do |name, table|
      safety_assured do
        add_reference :activity_logs, name, index: true
        add_foreign_key :activity_logs, table, column: "#{name}_id", validate: false
      end
    end
  end
end
