# frozen_string_literal: true

require "csv"
require "digest"

class ExternalEvidenceImportsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_manager!
  before_action :set_programs

  def index
    @batches = ExternalImportBatch.where(study_program_id: @programs.select(:id))
      .includes(:study_program, :uploaded_by).recent.page(params[:page]).per(25)
  end

  def new
    @study_program = selected_program
    @source_system = params[:source_system].to_s
  end

  def create
    @study_program = selected_program
    @source_system = params[:source_system].to_s
    file = params[:csv_file]
    raise ArgumentError, "Pilih berkas CSV atau XLSX terlebih dahulu." unless file.respond_to?(:read)
    extension = File.extname(file.original_filename.to_s).downcase
    raise ArgumentError, "Berkas harus berekstensi .csv atau .xlsx." unless extension.in?(%w[.csv .xlsx])
    raise ArgumentError, "Berkas lebih dari 10 MB." if file.size > ExternalEvidenceCsvImport::MAX_BYTES

    file_bytes = file.read
    csv_text = extension == ".xlsx" ? ExternalEvidenceSpreadsheet.new(file_bytes).to_csv : file_bytes
    importer = ExternalEvidenceCsvImport.new(study_program: @study_program, source_system: @source_system,
      csv_text: csv_text, actor: current_user, file_sha256: Digest::SHA256.hexdigest(file_bytes))

    if params[:stage] == "import"
      @batch = visible_batches.find(params[:batch_id])
      importer.import!(batch: @batch, confirmed_sha256: params[:file_sha256])
      redirect_to external_evidence_import_path(@batch), notice: "Impor berhasil: #{@batch.imported_count} baris bukti diproses."
    else
      @preview = importer.preview
      @batch = ExternalImportBatch.create!(study_program: @study_program, uploaded_by: current_user,
        source_system: @source_system, filename: file.original_filename,
        file_sha256: @preview.sha256, row_count: @preview.rows.length,
        row_results: preview_row_results(@preview))
      render :preview, status: :ok
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to external_evidence_imports_path, alert: "Batch atau program studi tidak ditemukan dalam lingkup akses Anda."
  rescue ArgumentError, ActiveRecord::RecordInvalid => error
    return redirect_to external_evidence_import_path(@batch), alert: error.message if @batch&.persisted?

    @error = error.message
    load_form_options
    render :new, status: :unprocessable_entity
  end

  def show
    @batch = visible_batches.includes(:study_program, :uploaded_by).find(params[:id])
  end

  def template
    headers = ExternalEvidenceCsvImport::REQUIRED_HEADERS + %w[instrument_code instrument_version score result feedback context_json metadata_json]
    csv = CSV.generate { |rows| rows << headers }
    send_data "\uFEFF#{csv}", filename: "jejak_external_evidence_template.csv", type: "text/csv; charset=utf-8"
  end

  private

  def authorize_manager!
    return if current_user.has_role?("admin") ||
      (current_user.has_role?("kaprodi") && current_user.study_program_id.present?) ||
      managed_programs.exists?

    redirect_to dashboard_path, alert: "Impor bukti eksternal memerlukan kewenangan admin, Kaprodi, atau penugasan pengelola data pada program studi."
  end

  def set_programs
    @programs = managed_programs
  end

  def managed_programs
    return StudyProgram.ordered if current_user.has_role?("admin")
    return StudyProgram.where(id: current_user.study_program_id) if current_user.has_role?("kaprodi") && current_user.study_program_id.present?

    assignments = UserAssignment.active.where(user: current_user, assignment_role: "external_data_manager",
      scope_type: "StudyProgram").where("user_assignments.scope_id = user_assignments.study_program_id")
    StudyProgram.where(id: assignments.select(:study_program_id))
  end

  def selected_program
    return current_user.study_program if current_user.study_program_bound?

    params[:study_program_id].present? ? @programs.find(params[:study_program_id]) : @programs.first
  end

  def visible_batches
    ExternalImportBatch.where(study_program_id: @programs.select(:id))
  end

  def load_form_options
    set_programs
    @study_program ||= @programs.first
    @source_system ||= params[:source_system].to_s
  end

  def preview_row_results(preview)
    preview.rows.map do |row|
      { "row" => row.number, "source_record_id" => row.source_record_id,
        "status" => row.errors.empty? ? "ready" : "invalid", "errors" => row.errors }
    end
  end
end
