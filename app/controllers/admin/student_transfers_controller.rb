# frozen_string_literal: true

require "csv"

class Admin::StudentTransfersController < ApplicationController
  MAX_FILE_SIZE = 2.megabytes

  before_action :authenticate_user!
  before_action :load_program_scopes

  def index
    prepare_index_state
  end

  # Preview a graduation or transfer-request CSV. The action remains pending
  # until the destination program accepts it.
  def create
    load_form
    return render_form_error("Aksi tidak valid.") unless StudentProgramTransitionCsv::MODES.include?(@mode)
    return render_form_error("Program studi asal tidak berada dalam cakupan kewenangan Anda.") unless @source_program
    return render_form_error("Anda tidak dapat mengajukan keputusan untuk program studi ini.") if
      @mode == "graduate" && !StudentTransferWorkflow.authorized_for?(current_user, "students.graduate", @source_program)
    return render_form_error("Anda tidak dapat mengajukan transfer dari program studi ini.") if
      @mode == "transfer" && !StudentTransferWorkflow.authorized_for?(current_user, "students.transfer.request", @source_program)
    if @mode == "transfer" && (@destination_program.nil? || @destination_program.id == @source_program.id)
      return render_form_error("Pilih program studi tujuan yang berbeda dari prodi asal.")
    end

    raw = uploaded_csv
    return render_form_error("Pilih berkas CSV atau tempelkan data CSV.") if raw.nil?
    return render_form_error("Berkas terlalu besar — maksimal 2 MB.") if raw.bytesize > MAX_FILE_SIZE

    @csv_raw = raw.force_encoding("UTF-8").scrub("").delete_prefix("\uFEFF")
    @processor = processor
    @matches = @processor.matches
    return render_form_error("CSV tidak berisi baris data.") if @matches.empty?

    if params[:apply] == "1"
      result = @processor.apply!
      redirect_to admin_student_transfers_path,
        notice: "#{result.processed} baris diproses, #{result.skipped} dilewati. Transfer tetap menunggu keputusan prodi tujuan."
    else
      prepare_index_state
      render :index, status: :unprocessable_entity
    end
  rescue StudentProgramTransitionCsv::Error, StudentTransferWorkflow::InvalidTransition => error
    render_form_error(error.message)
  rescue ActiveRecord::RecordInvalid => error
    render_form_error(error.record.errors.full_messages.to_sentence)
  rescue StudentTransferWorkflow::NotAuthorized
    redirect_to dashboard_path, alert: "Anda tidak memiliki kewenangan untuk tindakan ini pada program studi tersebut."
  end

  def template
    mode = params[:mode].to_s == "transfer" ? "transfer" : "graduate"
    headers = mode == "transfer" ? %w[email npm npm_tujuan angkatan_tujuan] : %w[email npm tanggal_lulus]
    send_data CSV.generate { |csv| csv << headers }, filename: "template_transfer_mahasiswa_#{mode}.csv", type: "text/csv"
  end

  def graduate
    enrollment = StudentProgramEnrollment.find_by!(id: params[:enrollment_id], study_program_id: @graduate_programs.map(&:id))
    StudentTransferWorkflow.new.graduate!(enrollment: enrollment, by: current_user,
      completed_on: params[:completed_on].presence || Date.current, reason: params[:reason])
    redirect_to admin_student_transfers_path, notice: "Status lulus mahasiswa berhasil dicatat. Riwayat program studi tetap tersimpan."
  rescue StudentTransferWorkflow::NotAuthorized, ActiveRecord::RecordNotFound
    redirect_to admin_student_transfers_path, alert: "Mahasiswa tidak berada dalam cakupan kewenangan Anda."
  rescue StudentTransferWorkflow::InvalidTransition => error
    redirect_to admin_student_transfers_path, alert: error.message
  end

  def accept
    transfer = StudentProgramTransfer.pending.find(params[:transfer_id])
    transfer.accept!(by: current_user)
    program_name = StudyProgram.find(transfer.destination_study_program_id).name
    redirect_to admin_student_transfers_path, notice: "Transfer diterima. Mahasiswa kini memiliki keanggotaan aktif di #{program_name}; riwayat asal tetap tersimpan."
  rescue StudentTransferWorkflow::NotAuthorized, ActiveRecord::RecordNotFound
    redirect_to admin_student_transfers_path, alert: "Pengajuan tidak tersedia dalam cakupan kewenangan Anda."
  rescue StudentTransferWorkflow::InvalidTransition, ActiveRecord::RecordInvalid => error
    redirect_to admin_student_transfers_path, alert: error.message
  end

  def reject
    transfer = StudentProgramTransfer.pending.find(params[:transfer_id])
    transfer.reject!(by: current_user, reason: params[:reason])
    redirect_to admin_student_transfers_path, notice: "Pengajuan transfer ditolak dan riwayat mahasiswa tidak diubah."
  rescue StudentTransferWorkflow::NotAuthorized, ActiveRecord::RecordNotFound
    redirect_to admin_student_transfers_path, alert: "Pengajuan tidak tersedia dalam cakupan kewenangan Anda."
  rescue StudentTransferWorkflow::InvalidTransition => error
    redirect_to admin_student_transfers_path, alert: error.message
  end

  private

  def load_program_scopes
    @graduate_programs = authorized_programs("students.graduate")
    @request_programs = authorized_programs("students.transfer.request")
    @accept_programs = authorized_programs("students.transfer.accept")
    return if [@graduate_programs, @request_programs, @accept_programs].any?(&:any?)

    redirect_to dashboard_path, alert: "Hak akses kelulusan atau transfer mahasiswa diperlukan."
  end

  def authorized_programs(permission)
    StudyProgram.ordered.select { |program| StudentTransferWorkflow.authorized_for?(current_user, permission, program) }
  end

  def load_form
    @mode = params[:mode].presence || "graduate"
    @source_program_id = params[:source_study_program_id].presence&.to_i
    @destination_program_id = params[:destination_study_program_id].presence&.to_i
    @source_program = @mode == "graduate" ? @graduate_programs.find { |program| program.id == @source_program_id } :
      @request_programs.find { |program| program.id == @source_program_id }
    @destination_programs = StudyProgram.ordered.reject { |program| program.id == @source_program_id }
    @destination_program = @destination_programs.find { |program| program.id == @destination_program_id }
  end

  def uploaded_csv
    file = params[:csv_file]
    return file.read if file.respond_to?(:read)
    return params[:csv_raw].to_s if params[:csv_raw].present?

    nil
  end

  def processor
    StudentProgramTransitionCsv.new(csv: @csv_raw, mode: @mode, source_program: @source_program,
      destination_program: @destination_program, actor: current_user, completed_on: params[:completed_on])
  end

  def render_form_error(message)
    prepare_index_state
    @matches = nil
    flash.now[:alert] = message
    render :index, status: :unprocessable_entity
  end

  def prepare_index_state
    @incoming_transfers ||= StudentProgramTransfer.includes(:student, :source_enrollment, :destination_study_program)
      .where(destination_study_program_id: @accept_programs.map(&:id)).order(created_at: :desc).limit(100)
    @outgoing_transfers ||= StudentProgramTransfer.includes(:student, :source_enrollment, :destination_study_program, :decided_by)
      .joins(:source_enrollment).where(student_program_enrollments: { study_program_id: @request_programs.map(&:id) })
      .order(created_at: :desc).limit(100)
    @source_programs ||= (@graduate_programs + @request_programs).uniq(&:id).sort_by(&:name)
    source = @request_programs.find { |program| program.id == params[:source_study_program_id].to_i }
    @destination_programs ||= StudyProgram.ordered.reject { |target| source.present? && target.id == source.id }
    @mode ||= params[:mode].presence || "graduate"
    @source_program_id ||= params[:source_study_program_id].presence&.to_i
    @destination_program_id ||= params[:destination_study_program_id].presence&.to_i
  end
end
