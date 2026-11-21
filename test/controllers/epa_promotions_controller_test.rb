require "test_helper"

class EpaPromotionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @student = User.create!(full_name: "Mahasiswa Profesi Promosi", email: "promosi@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: study_programs(:profesi_dokter))
    @student.roles << roles(:mahasiswa)
    framework = CompetencyFramework.create!(study_program: study_programs(:profesi_dokter),
      name: "Framework Promosi EPA", version: "91", education_stage: "professional")
    framework.competency_items.create!(title: "Kompetensi klinis", code: "D-01", level_type: "domain")
    epa = framework.epas.create!(code: "EPA-P1", title: "Melakukan asesmen klinis")
    EvidenceRequirement.create!(epa: epa, origin: "manual", source_type: "epa_observation",
      required_count: 1, fulfillment_rule: { "minimum_distinct_assessors" => 1, "minimum_distinct_dates" => 1 })
    framework.publish!
    epa.reload
    @scale = SupervisionScaleVersion.create!(code: "test_ottawa_promotion", name: "Ottawa test", version_label: "1",
      use_case: "retrospective_observation")
    observed_level = @scale.supervision_levels.create!(ordinal: 2, code: "guided", label: "Dengan arahan",
      description: "Supervisor memberi arahan.")
    prospective = SupervisionScaleVersion.create!(code: "test_chen_promotion", name: "Chen test", version_label: "1",
      use_case: "prospective_entrustment")
    @decision_level = prospective.supervision_levels.create!(ordinal: 7, code: "on_demand",
      label: "Supervisi on-demand", description: "Supervisor segera tersedia.")
    ClinicalRotation.create!(user: @student, preceptor: users(:wati), academic_period: academic_periods(:current_period),
      station_name: "Rotasi Promosi", start_date: 1.day.ago.to_date, end_date: 5.days.from_now.to_date)
    EpaObservation.create!(student: @student, epa: epa, observer: users(:wati), supervision_level: observed_level,
      observed_at: Time.current, narrative: "Melakukan asesmen klinis dengan supervisi.",
      status: "recorded", submitted_at: Time.current)
    @promotion = EpaPromotion.find_by!(student: @student, epa: epa)
  end

  test "preseptor melihat flag kesiapan, mengajukan dossier, dan Otoritas Akademik membuat keputusan final" do
    sign_in users(:wati)
    get epa_promotions_path
    assert_response :success
    assert_match "Siap dipromosikan", response.body

    patch promote_epa_promotion_path(@promotion)
    assert_equal "promoted", @promotion.reload.status
    assert Notification.exists?(recipient: @student, notifiable: @promotion, title: "EPA diajukan ke Otoritas Akademik")

    authority = users(:dedi)
    authority.update!(study_program: study_programs(:profesi_dokter))
    sign_in authority
    patch review_epa_promotion_path(@promotion), params: {
      recommendation: "approved", supervision_level_id: @decision_level.id, notes: "Panel menyetujui supervisi on-demand."
    }
    assert_equal "approved", @promotion.reload.status
    decision = EntrustmentDecision.find_by!(epa_promotion: @promotion)
    assert_equal @decision_level, decision.supervision_level
    assert_equal authority, decision.decided_by
    assert_equal 7, decision.level
    assert_equal @decision_level.label, decision.level_label
  end

  test "keputusan menunggu konsensus dua anggota panel bila ada dua otoritas prodi" do
    authority_one = users(:dedi)
    authority_one.update!(study_program: study_programs(:profesi_dokter))
    authority_two = User.create!(full_name: "Anggota Panel Kedua", email: "panel-kedua@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: study_programs(:profesi_dokter))
    authority_two.roles << roles(:kaprodi)
    @promotion.update!(status: "promoted", promoted_by: users(:wati), promoted_at: Time.current)

    sign_in authority_one
    assert_no_difference "EntrustmentDecision.count" do
      patch review_epa_promotion_path(@promotion), params: {
        recommendation: "approved", supervision_level_id: @decision_level.id, notes: "Rekomendasi setuju dari anggota pertama."
      }
    end
    assert_equal "under_review", @promotion.reload.status
    assert_difference "EntrustmentDecision.count", 1 do
      sign_in authority_two
      patch review_epa_promotion_path(@promotion), params: {
        recommendation: "approved", supervision_level_id: @decision_level.id, notes: "Rekomendasi setuju dari anggota kedua."
      }
    end
    assert_equal "approved", @promotion.reload.status
    assert_equal 2, @promotion.epa_promotion_reviews.count
    assert EntrustmentDecision.exists?(epa_promotion: @promotion)
  end

  test "preseptor tidak dapat mengeluarkan keputusan akademik" do
    sign_in users(:wati)
    @promotion.update!(status: "promoted", promoted_by: users(:wati), promoted_at: Time.current)

    assert_no_difference "EntrustmentDecision.count" do
      patch review_epa_promotion_path(@promotion), params: { status: "approved", notes: "Keputusan di luar kewenangan." }
    end
    assert_equal "promoted", @promotion.reload.status
  end

  test "preseptor yang ditugaskan dapat mengisi observasi mobile dan catatan tersimpan terpisah dari keputusan" do
    sign_in users(:wati)
    get new_epa_observation_path(student_id: @student.id, epa_id: @promotion.epa_id)
    assert_response :success
    assert_match "Observasi formatif EPA", response.body

    assert_difference "EpaObservation.count", 1 do
      post epa_observations_path, params: { epa_observation: {
        student_id: @student.id, epa_id: @promotion.epa_id, observed_at: Time.current.iso8601,
        supervision_level_id: @promotion.epa.epa_observations.first.supervision_level_id,
        clinical_rotation_id: @student.clinical_rotations.first.id, complexity: "moderate",
        narrative: "Mahasiswa melakukan tugas dengan arahan dan komunikasi yang baik."
      } }
    end
    assert_equal 0, EntrustmentDecision.where(student: @student).count
  end

  test "pengajar tanpa penugasan tidak dapat membuka observasi EPA mahasiswa" do
    sign_in users(:budi)

    get epa_observations_path(student_id: @student.id)

    assert_redirected_to dashboard_path
  end
end
