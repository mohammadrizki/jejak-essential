require "test_helper"

class Admin::StudentTransfersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @source_manager = users(:dedi)
    @source = study_programs(:sarjana_kedokteran)
    @destination = study_programs(:profesi_dokter)
    grant_permission_to_role!("kaprodi", "students.graduate")
    grant_permission_to_role!("kaprodi", "students.transfer.request")
    grant_permission_to_role!("kaprodi", "students.transfer.accept")
    @student = users(:siti)
    @student.update!(study_program: @source, identifier_number: "S-22001", cohort_year: 2022)
    @source_enrollment = StudentProgramEnrollment.create!(user: @student, study_program: @source,
      identifier_number: @student.identifier_number, cohort_year: 2022, status: "active", started_on: Date.new(2022, 1, 1))
  end

  test "kelulusan dan pengajuan CSV mempertahankan akun serta menunggu penerimaan prodi tujuan" do
    sign_in @source_manager
    post admin_student_transfers_path, params: {
      mode: "graduate", source_study_program_id: @source.id,
      csv_file: csv_upload("email,npm,tanggal_lulus\n,S-22001,2026-06-30\n")
    }
    assert_response :unprocessable_entity
    assert_match "1 dari 1 baris siap diproses", response.body
    post admin_student_transfers_path, params: {
      mode: "graduate", source_study_program_id: @source.id, apply: "1",
      csv_raw: "email,npm,tanggal_lulus\n,S-22001,2026-06-30\n"
    }
    assert_redirected_to admin_student_transfers_path
    assert @source_enrollment.reload.graduated?
    assert_equal @source, @student.reload.study_program

    post admin_student_transfers_path, params: {
      mode: "transfer", source_study_program_id: @source.id, destination_study_program_id: @destination.id,
      csv_file: csv_upload("email,npm_tujuan,angkatan_tujuan\nsiti@example.com,P-26001,2026\n")
    }
    assert_response :unprocessable_entity
    assert_match "1 dari 1 baris siap diproses", response.body
    post admin_student_transfers_path, params: {
      mode: "transfer", source_study_program_id: @source.id, destination_study_program_id: @destination.id,
      apply: "1", csv_raw: "email,npm_tujuan,angkatan_tujuan\nsiti@example.com,P-26001,2026\n"
    }
    transfer = StudentProgramTransfer.find_by!(student: @student)
    assert_equal "pending", transfer.status
    assert_equal @source, @student.reload.study_program
    assert_equal @source_enrollment, transfer.source_enrollment
  end

  test "hanya kaprodi prodi tujuan yang menerima dan riwayat asal tetap ada" do
    @source_enrollment.update!(status: "graduated", completed_on: Date.new(2026, 6, 30))
    transfer = StudentProgramTransfer.create!(student: @student, source_enrollment: @source_enrollment,
      destination_study_program: @destination, requested_by: @source_manager, status: "pending",
      destination_identifier_number: "P-26002", destination_cohort_year: 2026)
    destination_manager = User.create!(full_name: "Kaprodi Profesi", email: "kaprodi-profesi@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: @destination,
      active_role: roles(:kaprodi))
    grant_role_in_program!(destination_manager, "kaprodi", @destination)

    sign_in @source_manager
    patch accept_admin_student_transfers_path, params: { transfer_id: transfer.id }
    assert_redirected_to admin_student_transfers_path
    assert_equal "pending", transfer.reload.status
    assert_equal @source, @student.reload.study_program

    sign_in destination_manager
    patch accept_admin_student_transfers_path, params: { transfer_id: transfer.id }
    assert_redirected_to admin_student_transfers_path
    assert_equal "accepted", transfer.reload.status
    assert_equal @destination, @student.reload.study_program
    assert_equal "graduated", @source_enrollment.reload.status
    assert_equal "active", transfer.destination_enrollment.reload.status
    assert_equal @student.id, transfer.destination_enrollment.user_id

    sign_in @source_manager
    get admin_student_transfers_path
    assert_response :success
    assert_match "Riwayat pengajuan dari prodi asal", response.body
    assert_match "Diterima", response.body
  end

  test "superadmin tanpa permission akademik tidak mendapat akses transfer" do
    admin = users(:budi)
    grant_bootstrapped_system_admin!(admin)
    sign_in admin
    get admin_student_transfers_path
    assert_redirected_to dashboard_path
    assert_equal @source, @student.reload.study_program
  end

  test "legacy relabel hanya mengarahkan ke alur transfer dan tidak mengubah prodi" do
    grant_permission_to_role!("admin", "users.manage")
    admin = users(:budi)
    grant_bootstrapped_system_admin!(admin)
    sign_in admin
    get new_admin_student_relabel_path
    assert_redirected_to admin_student_transfers_path
    post admin_student_relabel_path, params: {
      target_study_program_id: @destination.id, csv_raw: "email\nsiti@example.com\n", apply: "1"
    }
    assert_redirected_to admin_student_transfers_path
    assert_equal @source, @student.reload.study_program
  end

  private

  def csv_upload(content)
    Rack::Test::UploadedFile.new(StringIO.new(content), "text/csv", original_filename: "transfer.csv")
  end
end
