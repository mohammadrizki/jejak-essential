# frozen_string_literal: true

require "csv"

# Legacy endpoint retained so old bookmarks fail safely into the new workflow.
class Admin::StudentRelabelsController < ApplicationController
  before_action :authenticate_user!
  def new = redirect_to admin_student_transfers_path, notice: "Alur Relabel Prodi telah diganti dengan Transfer Mahasiswa yang mempertahankan riwayat."
  def create = redirect_to admin_student_transfers_path, alert: "Relabel langsung dinonaktifkan. Gunakan alur Transfer Mahasiswa."
  def template = redirect_to template_admin_student_transfers_path(format: :csv)
end
