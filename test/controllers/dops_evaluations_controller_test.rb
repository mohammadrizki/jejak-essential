require "test_helper"

class DopsEvaluationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "mahasiswa tidak bisa membuat evaluasi" do
    sign_in users(:siti)
    get new_dops_evaluation_path
    assert_response :redirect
  end

  test "admin teknis tanpa assignment tidak dapat melihat hasil DOPS" do
    admin = User.create!(full_name: "Admin DOPS", email: "admin-dops@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current)
    admin.roles << roles(:admin)
    sign_in admin

    get dops_evaluation_path(dops_evaluations(:dops_siti_infus))

    assert_response :redirect
    get new_dops_evaluation_path
    assert_response :redirect
  end

  test "mahasiswa bisa melihat evaluasi miliknya sendiri" do
    sign_in users(:siti)
    get dops_evaluation_path(dops_evaluations(:dops_siti_infus))
    assert_response :success
  end

  test "mahasiswa tidak bisa melihat evaluasi milik mahasiswa lain" do
    other = User.create!(full_name: "Lain", email: "dopslain@example.com", password: "rahasia-kuat-1", confirmed_at: Time.current)
    other.roles << roles(:mahasiswa)

    sign_in other
    get dops_evaluation_path(dops_evaluations(:dops_siti_infus))
    assert_response :redirect
  end

  test "dosen membuat evaluasi DOPS baru" do
    sign_in users(:budi)

    assert_difference "DopsEvaluation.count", 1 do
      post dops_evaluations_path, params: {
        dops_evaluation: {
          student_id: users(:siti).id, clinical_rotation_id: clinical_rotations(:ongoing_rotation_siti).id,
          procedure_name: "Kateter Urin", evaluated_at: Date.current,
          scores: { komunikasi: 7, profesionalisme: 8, penilaian_global: 7 }
        }
      }
    end

    dops = DopsEvaluation.order(:id).last
    assert_equal users(:budi), dops.evaluator
    assert_redirected_to dops_evaluation_path(dops)
  end

  test "aktivasi WPBA mengikuti program mahasiswa pada assignment lintas program" do
    assessor = users(:budi)
    assessor.update!(study_program: study_programs(:profesi_dokter))
    admin = User.create!(full_name: "Admin modul", email: "admin-modul-dops@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current)
    admin.roles << roles(:admin)
    ModuleConfiguration.for(assessor.study_program).update!({ wpba: false }, actor: admin)
    sign_in assessor

    assert_difference "DopsEvaluation.count", 1 do
      post dops_evaluations_path, params: { dops_evaluation: {
        student_id: users(:siti).id, clinical_rotation_id: clinical_rotations(:ongoing_rotation_siti).id,
        procedure_name: "Pemeriksaan abdomen", evaluated_at: Date.current,
        scores: { komunikasi: 7, profesionalisme: 8, penilaian_global: 7 }
      } }
    end
    assert_response :redirect
    assert_match "berhasil disimpan", flash[:notice]
  end

  test "penilai tidak dapat membuat atau mengoreksi WPBA saat modul program mahasiswa nonaktif" do
    admin = User.create!(full_name: "Admin modul", email: "admin-modul-dops-disabled@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current)
    admin.roles << roles(:admin)
    ModuleConfiguration.for(users(:siti).study_program).update!({ wpba: false }, actor: admin)
    sign_in users(:budi)

    assert_no_difference "DopsEvaluation.count" do
      post dops_evaluations_path, params: { dops_evaluation: {
        student_id: users(:siti).id, clinical_rotation_id: clinical_rotations(:ongoing_rotation_siti).id,
        procedure_name: "Pemeriksaan abdomen", evaluated_at: Date.current,
        scores: { komunikasi: 7, profesionalisme: 8, penilaian_global: 7 }
      } }
    end
    assert_response :redirect

    get correction_dops_evaluation_path(dops_evaluations(:dops_siti_infus))
    assert_response :redirect
  end

  test "mahasiswa lain (bukan penilai) tidak bisa menyunting evaluasi" do
    dosen_lain = User.create!(full_name: "Dosen Lain", email: "dosenlain@example.com", password: "rahasia-kuat-1", confirmed_at: Time.current)
    dosen_lain.roles << roles(:dosen)

    sign_in dosen_lain
    get edit_dops_evaluation_path(dops_evaluations(:dops_siti_infus))
    assert_response :redirect
  end

  test "evaluator bisa menyimpan draf lalu mengirimkannya" do
    sign_in users(:budi)

    post dops_evaluations_path, params: {
      dops_evaluation: {
        student_id: users(:siti).id, clinical_rotation_id: clinical_rotations(:ongoing_rotation_siti).id,
        procedure_name: "Jahit Luka", evaluated_at: Date.current, status: "draft",
        scores: { komunikasi: 7, profesionalisme: 8, penilaian_global: 7 }
      }
    }
    dops = DopsEvaluation.order(:id).last
    assert dops.draft?

    assert_difference "Notification.count", 1 do
      patch submit_dops_evaluation_path(dops)
    end
    assert dops.reload.submitted?
  end

  test "koreksi DOPS membuat versi baru, mempertahankan instrumen, dan tidak menimpa nilai final" do
    original = dops_evaluations(:dops_siti_infus)
    sign_in users(:budi)

    post create_correction_dops_evaluation_path(original), params: {
      correction_reason: "Nilai penilaian global salah dicatat saat memindahkan hasil observasi."
    }
    correction = DopsEvaluation.order(:id).last

    assert_redirected_to edit_dops_evaluation_path(correction)
    assert_equal original, correction.corrects
    assert_nil correction.wpba_instrument_version_id if original.wpba_instrument_version_id.nil?
    assert_equal original.wpba_instrument_version_id, correction.wpba_instrument_version_id if original.wpba_instrument_version_id.present?
    patch submit_dops_evaluation_path(correction)
    assert_redirected_to dops_evaluation_path(correction)
    assert original.reload.submitted?
    assert_not_includes DopsEvaluation.submitted, original
    assert_includes DopsEvaluation.submitted, correction
    assert_equal original.source_activity_key, correction.source_activity_key

    get dops_evaluation_path(correction)
    assert_response :success
    assert_match "Koreksi dari", response.body
    assert_match "Nilai penilaian global", response.body
  end
end
