# frozen_string_literal: true

# Role mendefinisikan kumpulan permission. Cakupan pemberian role berada pada
# UserRole; tugas atas mahasiswa/rotasi tertentu tetap dicatat di UserAssignment.
class Role < ApplicationRecord
  # Peran yang boleh dipilih sendiri di form Daftar publik — hanya mahasiswa.
  # Dosen/preseptor membuka kasus klinis seluruh mahasiswa (termasuk Break
  # Glass identitas pasien) dan kaprodi/admin seluruh prodi/instalasi, jadi
  # semuanya hanya diberikan admin lewat Konfigurasi → Pengguna (sunting atau
  # impor CSV). Kalau dosen bisa diklaim sendiri, siapa pun di internet bisa
  # membaca data pasien.
  SELF_REGISTRABLE_CODES = %w[mahasiswa].freeze
  BUILT_IN_CODES = %w[mahasiswa dosen preseptor kaprodi admin tenaga_kependidikan superadmin].freeze

  has_many :user_roles, dependent: :destroy
  has_many :users, through: :user_roles
  has_many :role_permissions, dependent: :destroy
  has_many :system_permissions, through: :role_permissions

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :code, format: { with: /\A[a-z][a-z0-9_]*\z/ }

  before_destroy :protect_system_roles

  def self.self_registrable?(code)
    SELF_REGISTRABLE_CODES.include?(code.to_s)
  end

  def system_role?
    BUILT_IN_CODES.include?(code)
  end

  private

  def protect_system_roles
    throw :abort if system_role?
  end
end
