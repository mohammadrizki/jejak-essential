require "test_helper"

class MiniCexEvaluationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "mahasiswa tidak bisa membuat evaluasi" do
    sign_in users(:siti)
    get new_mini_cex_evaluation_path
    assert_response :redirect
  end

  test "admin teknis tanpa assignment tidak dapat melihat hasil Mini-CEX" do
    admin = User.create!(full_name: "Admin WPBA", email: "admin-wpba@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current)
    admin.roles << roles(:admin)
    sign_in admin

    get mini_cex_evaluation_path(mini_cex_evaluations(:minicex_siti_demam))

    assert_response :redirect
  end

  test "dosen membuat evaluasi Mini-CEX baru" do
    sign_in users(:budi)

    assert_difference "MiniCexEvaluation.count", 1 do
      post mini_cex_evaluations_path, params: {
        mini_cex_evaluation: {
          student_id: users(:siti).id, clinical_rotation_id: clinical_rotations(:ongoing_rotation_siti).id,
          case_description: "Konsultasi hipertensi", evaluated_at: Date.current,
          scores: { komunikasi: 7, profesionalisme: 8 }, global_rating: "performed"
        }
      }
    end

    assert_redirected_to mini_cex_evaluation_path(MiniCexEvaluation.order(:id).last)
  end

  test "evaluator mengoreksi hasil terkirim tanpa mengubah riwayat dan mengganti observasi aktif" do
    original = mini_cex_evaluations(:minicex_siti_demam)
    sign_in users(:budi)
    original_updated_at = original.updated_at

    get correction_mini_cex_evaluation_path(original)
    assert_response :success
    assert_match "Evaluasi terkirim tetap tersimpan", response.body

    assert_difference "MiniCexEvaluation.count", 1 do
      post create_correction_mini_cex_evaluation_path(original), params: {
        correction_reason: "Skor komunikasi pada catatan awal salah dipindahkan dari lembar penilaian."
      }
    end
    correction = MiniCexEvaluation.order(:id).last
    assert_equal original, correction.corrects
    assert correction.draft?
    assert_equal original_updated_at, original.reload.updated_at
    assert_includes MiniCexEvaluation.submitted, original

    patch submit_mini_cex_evaluation_path(correction)
    assert_redirected_to mini_cex_evaluation_path(correction)
    assert correction.reload.submitted?
    assert_includes MiniCexEvaluation.submitted_history, original
    assert_not_includes MiniCexEvaluation.submitted, original
    assert_includes MiniCexEvaluation.submitted, correction
    assert_equal original.source_activity_key, correction.source_activity_key
    assert_raises(ActiveRecord::RecordNotDestroyed) { original.destroy! }

    get mini_cex_evaluation_path(original)
    assert_response :success
    assert_select "a[href=?]", mini_cex_evaluation_path(correction), text: /Terkirim/
    get mini_cex_evaluation_path(correction)
    assert_response :success
    assert_match "Alasan: Skor komunikasi", response.body
  end

  test "koreksi yang terkirim meneruskan tautan Syarat Bukti dan tetap satu kesempatan observasi" do
    original = mini_cex_evaluations(:minicex_siti_demam)
    requirement = EvidenceRequirement.create!(origin: "manual", competency_item: competency_items(:sub_anamnesis),
      source_type: "wpba", required_count: 1)
    old_record = EvidenceRecord.create!(evidence_requirement: requirement, mini_cex_evaluation: original,
      evidence_date: original.evaluated_at, result: "other")
    sign_in users(:budi)

    post create_correction_mini_cex_evaluation_path(original), params: {
      correction_reason: "Penilaian global harus mengikuti nilai pada formulir bertanda tangan."
    }
    correction = MiniCexEvaluation.order(:id).last
    patch submit_mini_cex_evaluation_path(correction)

    replacement = requirement.evidence_records.find_by!(mini_cex_evaluation: correction)
    progress = EvidenceRequirementProgress.new(requirement, student: users(:siti)).call
    assert_equal old_record.evidence_source.activity_key, replacement.evidence_source.activity_key
    assert_equal 1, progress.opportunity_count
    assert_equal [replacement.id], progress.eligible_record_ids
  end

  test "dosen tanpa penugasan rotasi tidak dapat menilai mahasiswa tersebut" do
    unassigned = User.create!(full_name: "Dosen Tanpa Penugasan", email: "unassigned@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current)
    unassigned.roles << roles(:dosen)
    sign_in unassigned

    assert_no_difference "MiniCexEvaluation.count" do
      post mini_cex_evaluations_path, params: {
        mini_cex_evaluation: {
          student_id: users(:siti).id, clinical_rotation_id: clinical_rotations(:ongoing_rotation_siti).id,
          case_description: "Konsultasi hipertensi", evaluated_at: Date.current,
          scores: { komunikasi: 7, profesionalisme: 8 }, global_rating: "performed"
        }
      }
    end
    assert_response :redirect
  end
end
