require "test_helper"

class EpaPromotionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @student = User.create!(full_name: "Mahasiswa Profesi Promosi", email: "promosi@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: study_programs(:profesi_dokter))
    @student.roles << roles(:mahasiswa)
    authority = users(:dedi)
    authority.update!(study_program: study_programs(:profesi_dokter))
    UserAssignment.create!(user: authority, assigned_by: authority, study_program: study_programs(:profesi_dokter),
      assignment_role: "epa_panel_member", scope_type: "User", scope_id: @student.id,
      reason: "Ditunjuk sebagai otoritas panel EPA mahasiswa.")
    framework = CompetencyFramework.create!(study_program: study_programs(:profesi_dokter),
      name: "Framework Promosi EPA", version: "91", education_stage: "profesi")
    framework.competency_items.create!(title: "Kompetensi klinis", code: "D-01", level_type: "domain")
    epa = framework.epas.create!(code: "EPA-P1", title: "Melakukan asesmen klinis")
    @unpromoted_epa = framework.epas.create!(code: "EPA-P2", title: "Mengelola tindak lanjut klinis")
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
    @rotation = ClinicalRotation.create!(user: @student, preceptor: users(:wati), academic_period: academic_periods(:current_period),
      station_name: "Rotasi Promosi", start_date: 1.day.ago.to_date, end_date: 5.days.from_now.to_date)
    EpaObservation.create!(student: @student, epa: epa, observer: users(:wati), clinical_rotation: @rotation,
      supervision_level: observed_level,
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
    chair = assign_chair
    sign_in authority
    patch review_epa_promotion_path(@promotion), params: {
      recommendation: "approved", supervision_level_id: @decision_level.id, notes: "Panel menyetujui supervisi on-demand."
    }
    assert_equal "under_review", @promotion.reload.status
    assert @promotion.quorum_reached_at
    assert_empty EntrustmentDecision.where(epa_promotion: @promotion)
    assert Notification.exists?(recipient: chair, notifiable: @promotion, title: "Dossier EPA siap disahkan")

    assert_no_difference "EntrustmentDecision.count" do
      sign_in authority
      patch finalize_epa_promotion_path(@promotion), params: {
        recommendation: "approved", supervision_level_id: @decision_level.id,
        notes: "Anggota panel tidak memiliki assignment ketua panel."
      }
    end
    assert_equal "under_review", @promotion.reload.status

    sign_in chair
    patch finalize_epa_promotion_path(@promotion), params: {
      recommendation: "approved", supervision_level_id: @decision_level.id,
      review_due_at: 6.months.from_now.to_date, notes: "Mengesahkan rekomendasi panel berdasarkan dossier longitudinal."
    }
    assert_equal "approved", @promotion.reload.status
    assert_equal chair, @promotion.finalized_by
    assert @promotion.dossier_snapshot.present?
    decision = EntrustmentDecision.find_by!(epa_promotion: @promotion)
    assert_equal @decision_level, decision.supervision_level
    assert_equal chair, decision.decided_by
    assert_equal 7, decision.level
    assert_equal @decision_level.label, decision.level_label
    assert decision.review_due_at
  end

  test "preseptor yang ditugaskan dapat mencatat keputusan ad hoc terpisah dari keputusan panel" do
    sign_in users(:wati)
    get new_entrustment_decision_path(student_id: @student.id)
    assert_response :success
    assert_match "Keputusan Entrustment Ad Hoc", response.body

    assert_difference "EntrustmentDecision.where(decision_kind: 'ad_hoc').count", 1 do
      post entrustment_decisions_path, params: { student_id: @student.id, entrustment_decision: {
        epa_id: @promotion.epa_id, supervision_scale_version_id: @decision_level.supervision_scale_version_id,
        supervision_level_id: @decision_level.id, justification: "Dapat menjalankan aktivitas dengan supervisi tersedia.",
        scope_limitations: "Kasus dengan kompleksitas rendah.", setting: "Bangsal", case_complexity: "Rendah",
        valid_from: Time.current.iso8601
      } }
    end
    decision = EntrustmentDecision.order(:id).last
    assert_equal "ad_hoc", decision.decision_kind
    assert_equal "active", decision.decision_status
    assert_nil decision.epa_promotion_id
    assert_equal @decision_level, decision.supervision_level
    assert_equal "issued", decision.events.last.event_type
    assert_redirected_to entrustment_decisions_path(student_id: @student.id)
    follow_redirect!
    assert_response :success
    assert_match "Ad hoc aktif", response.body
  end

  test "keputusan menunggu konsensus dua anggota panel bila ada dua otoritas prodi" do
    study_programs(:profesi_dokter).update!(epa_panel_quorum: 2)
    authority_one = users(:dedi)
    authority_one.update!(study_program: study_programs(:profesi_dokter))
    authority_two = User.create!(full_name: "Anggota Panel Kedua", email: "panel-kedua@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: study_programs(:profesi_dokter))
    authority_two.roles << roles(:kaprodi)
    UserAssignment.create!(user: authority_two, assigned_by: users(:dedi),
      study_program: study_programs(:profesi_dokter), assignment_role: "epa_panel_member",
      scope_type: "User", scope_id: @student.id, reason: "Ditunjuk sebagai anggota kedua panel EPA.")
    @promotion.update!(status: "promoted", promoted_by: users(:wati), promoted_at: Time.current)

    sign_in authority_one
    assert_no_difference "EntrustmentDecision.count" do
      patch review_epa_promotion_path(@promotion), params: {
        recommendation: "approved", supervision_level_id: @decision_level.id, notes: "Rekomendasi setuju dari anggota pertama."
      }
    end
    assert_equal "under_review", @promotion.reload.status
    sign_in authority_two
    patch review_epa_promotion_path(@promotion), params: {
      recommendation: "approved", supervision_level_id: @decision_level.id, notes: "Rekomendasi setuju dari anggota kedua."
    }
    assert_equal "under_review", @promotion.reload.status
    assert_equal 2, @promotion.epa_promotion_reviews.count
    chair = assign_chair
    assert_difference "EntrustmentDecision.count", 1 do
      sign_in chair
      patch finalize_epa_promotion_path(@promotion), params: {
        recommendation: "approved", supervision_level_id: @decision_level.id,
        notes: "Mengesahkan rekomendasi quorum dua anggota panel ini."
      }
    end
    assert_equal "approved", @promotion.reload.status
    assert EntrustmentDecision.exists?(epa_promotion: @promotion)
  end

  test "panel can restrict entrustment, later revoke it, and retain immutable vote history" do
    authority = users(:dedi)
    authority.update!(study_program: study_programs(:profesi_dokter))
    @promotion.update!(status: "promoted", promoted_by: users(:wati), promoted_at: Time.current)
    sign_in authority

    patch review_epa_promotion_path(@promotion), params: {
      recommendation: "restricted", supervision_level_id: @decision_level.id,
      notes: "Disetujui dengan supervisi langsung untuk pasien berkompleksitas tinggi."
    }
    assert_equal "under_review", @promotion.reload.status
    chair = assign_chair
    sign_in chair
    patch finalize_epa_promotion_path(@promotion), params: {
      recommendation: "restricted", supervision_level_id: @decision_level.id,
      notes: "Mengesahkan pembatasan ruang lingkup sesuai rekomendasi panel."
    }
    assert_equal "restricted", @promotion.reload.status
    decision = EntrustmentDecision.find_by!(epa_promotion: @promotion)
    assert_equal @decision_level, decision.supervision_level
    assert_equal 1, @promotion.epa_promotion_reviews.first.events.count

    sign_in users(:dedi)
    patch review_epa_promotion_path(@promotion), params: {
      recommendation: "revoked", notes: "Kewenangan dihentikan setelah isu keselamatan ditinjau panel."
    }
    assert_equal "under_review", @promotion.reload.status
    sign_in chair
    patch finalize_epa_promotion_path(@promotion), params: {
      recommendation: "revoked", notes: "Mencabut kewenangan setelah panel menilai risiko keselamatan terbaru."
    }
    assert_equal "revoked", @promotion.reload.status
    assert decision.reload.revoked?
    assert_equal 2, @promotion.epa_promotion_reviews.first.events.count
  end

  test "updated panel vote appends a review event instead of erasing the previous vote" do
    study_programs(:profesi_dokter).update!(epa_panel_quorum: 2)
    authority_one = users(:dedi)
    authority_one.update!(study_program: study_programs(:profesi_dokter))
    authority_two = User.create!(full_name: "Anggota Panel Ubah Suara", email: "panel-ubah@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: study_programs(:profesi_dokter))
    authority_two.roles << roles(:kaprodi)
    UserAssignment.create!(user: authority_two, assigned_by: users(:dedi),
      study_program: study_programs(:profesi_dokter), assignment_role: "epa_panel_member",
      scope_type: "User", scope_id: @student.id, reason: "Ditunjuk sebagai anggota kedua panel EPA.")
    @promotion.update!(status: "promoted", promoted_by: users(:wati), promoted_at: Time.current)

    sign_in authority_one
    patch review_epa_promotion_path(@promotion), params: {
      recommendation: "deferred", notes: "Tunda untuk telaah keselamatan tambahan."
    }
    patch review_epa_promotion_path(@promotion), params: {
      recommendation: "approved", supervision_level_id: @decision_level.id,
      notes: "Setuju setelah bukti longitudinal dan keselamatan ditelaah."
    }
    assert_equal 2, @promotion.epa_promotion_reviews.find_by!(reviewer: authority_one).events.count
    assert_equal "under_review", @promotion.reload.status

    sign_in authority_two
    patch review_epa_promotion_path(@promotion), params: {
      recommendation: "approved", supervision_level_id: @decision_level.id,
      notes: "Setuju untuk target supervisi yang sama."
    }
    assert_equal "under_review", @promotion.reload.status
    chair = assign_chair
    sign_in chair
    patch finalize_epa_promotion_path(@promotion), params: {
      recommendation: "approved", supervision_level_id: @decision_level.id,
      notes: "Ketua panel mengesahkan suara mayoritas yang konsisten."
    }
    assert_equal "approved", @promotion.reload.status
  end

  test "preseptor tidak dapat mengeluarkan keputusan akademik" do
    sign_in users(:wati)
    @promotion.update!(status: "promoted", promoted_by: users(:wati), promoted_at: Time.current)

    assert_no_difference "EntrustmentDecision.count" do
      patch review_epa_promotion_path(@promotion), params: { status: "approved", notes: "Keputusan di luar kewenangan." }
    end
    assert_equal "promoted", @promotion.reload.status
  end

  test "Kaprodi tanpa assignment panel tidak dapat memutus EPA" do
    authority = User.create!(full_name: "Kaprodi Tanpa Tugas", email: "kaprodi.tanpa.tugas@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: study_programs(:profesi_dokter))
    authority.roles << roles(:kaprodi)
    @promotion.update!(status: "promoted", promoted_by: users(:wati), promoted_at: Time.current)
    sign_in authority

    assert_no_difference "EntrustmentDecision.count" do
      patch review_epa_promotion_path(@promotion), params: {
        recommendation: "deferred", notes: "Tunda keputusan untuk observasi tambahan."
      }
    end
    assert_equal "promoted", @promotion.reload.status
  end

  test "admin teknis tanpa assignment tidak dapat membuka dossier EPA mahasiswa" do
    admin = User.create!(full_name: "Admin EPA Teknis", email: "admin-epa@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current)
    admin.roles << roles(:admin)
    sign_in admin

    get epa_observations_path(student_id: @student.id)

    assert_redirected_to dashboard_path
  end

  test "admin teknis yang tercatat pada rotasi historis tidak dapat melihat dossier atau mengisi observasi EPA" do
    admin = User.create!(full_name: "Admin EPA pada Rotasi", email: "admin-epa-rotasi@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current)
    admin.roles << roles(:admin)
    rotation = @student.clinical_rotations.first
    # Simulasikan relasi data lama yang tersimpan sebelum validasi role preseptor.
    rotation.update_column(:preceptor_id, admin.id)
    sign_in admin

    get epa_observations_path(student_id: @student.id)
    assert_redirected_to dashboard_path
    get new_epa_observation_path(student_id: @student.id, epa_id: @promotion.epa_id)
    assert_redirected_to dashboard_path
  end

  test "admin teknis tanpa assignment tidak melihat daftar promosi atau narasi panel" do
    admin = User.create!(full_name: "Admin Daftar EPA", email: "admin-daftar-epa@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current)
    admin.roles << roles(:admin)
    @promotion.epa_promotion_reviews.create!(reviewer: users(:dedi), recommendation: "deferred",
      notes: "Catatan panel yang harus tetap terbatas kepada anggota yang ditugaskan.")
    sign_in admin

    get epa_promotions_path

    assert_response :success
    assert_no_match @student.full_name, response.body
    assert_no_match "Catatan panel yang harus tetap terbatas", response.body
  end

  test "hanya anggota panel EPA yang ditugaskan dapat menyelesaikan tindak lanjut keselamatan" do
    safety_observation = EpaObservation.create!(student: @student, epa: @promotion.epa, observer: users(:wati),
      supervision_level: @promotion.epa.epa_observations.first.supervision_level, observed_at: Time.current,
      narrative: "Observasi menunjukkan potensi risiko yang harus ditinjau panel.", status: "recorded",
      submitted_at: Time.current, safety_flag: true)
    admin = User.create!(full_name: "Admin Keselamatan", email: "admin-keselamatan@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current)
    admin.roles << roles(:admin)

    sign_in admin
    patch resolve_safety_epa_observation_path(safety_observation), params: {
      safety_resolution: "Tindak lanjut dicatat oleh akun teknis yang tidak berwenang."
    }
    assert_nil safety_observation.reload.safety_resolved_at

    sign_in users(:dedi)
    patch resolve_safety_epa_observation_path(safety_observation), params: {
      safety_resolution: "Kasus ditinjau panel dan rencana supervisi tambahan sudah ditetapkan."
    }
    assert_not_nil safety_observation.reload.safety_resolved_at
    assert_equal users(:dedi), safety_observation.safety_resolved_by
  end

  test "preseptor yang ditugaskan dapat mengisi observasi mobile dan catatan tersimpan terpisah dari keputusan" do
    admin = users(:budi)
    admin.roles << roles(:admin)
    ModuleConfiguration.for(@student.study_program).update!({ "wpba" => "0" }, actor: admin)
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

  test "dosen yang ditugaskan khusus sebagai pengamat EPA dapat mengisi observasi" do
    observer = users(:budi)
    observer.update!(study_program: study_programs(:profesi_dokter))
    UserAssignment.create!(user: observer, assigned_by: users(:dedi),
      study_program: study_programs(:profesi_dokter), assignment_role: "epa_observer",
      scope_type: "User", scope_id: @student.id,
      reason: "Ditugaskan untuk mengamati EPA mahasiswa pada periode ini.")
    sign_in observer

    get new_epa_observation_path(student_id: @student.id, epa_id: @promotion.epa_id)
    assert_response :success

    assert_difference "EpaObservation.count", 1 do
      post epa_observations_path, params: { epa_observation: {
        student_id: @student.id, epa_id: @promotion.epa_id, observed_at: Time.current.iso8601,
        supervision_level_id: @promotion.epa.epa_observations.first.supervision_level_id,
        complexity: "moderate", narrative: "Pengamat yang ditugaskan mencatat komunikasi dan keselamatan kasus."
      } }
    end
    assert_equal 0, EntrustmentDecision.where(student: @student).count
  end

  test "tinjauan ulang yang jatuh tempo membuat dossier baru dan keputusan lama tetap aktif sampai disahkan" do
    @promotion.update!(status: "approved", reviewed_by: users(:dedi), reviewed_at: Time.current,
      finalized_by: users(:dedi), finalized_at: Time.current)
    old_decision = EntrustmentDecision.decide!(student: @student, epa: @promotion.epa, level: 3,
      justification: "Keputusan entrustment lama telah mencapai masa tinjauan yang ditetapkan.",
      decided_by: users(:dedi), epa_promotion: @promotion, review_due_at: 1.day.ago)

    sign_in users(:wati)
    post request_epa_renewal_path(old_decision)

    assert_redirected_to epa_promotions_path
    renewal = EpaPromotion.find_by!(renewal_of_decision: old_decision)
    assert_equal "promoted", renewal.status
    assert_nil old_decision.reload.superseded_at
    UserAssignment.create!(user: users(:budi), assigned_by: users(:dedi),
      study_program: study_programs(:profesi_dokter), assignment_role: "epa_panel_member",
      scope_type: "EpaPromotion", scope_id: @promotion.id,
      reason: "Anggota panel dossier lama tetap meninjau renewal yang merujuk keputusan ini.")
    assert AssignmentAuthorization.assigned?(user: users(:dedi), role: "epa_panel_member",
      student: @student, object: renewal), "appointment scoped to the original dossier must cover its explicit renewal"
    assert AssignmentAuthorization.assigned?(user: users(:budi), role: "epa_panel_member",
      student: @student, object: renewal), "an explicit renewal reference must carry dossier-scoped panel appointments"

    sign_in users(:dedi)
    patch review_epa_promotion_path(renewal), params: {
      recommendation: "approved", supervision_level_id: @decision_level.id,
      notes: "Observasi baru mendukung pembaruan target supervisi yang diajukan panel."
    }
    assert renewal.reload.quorum_reached_at
    assert_nil old_decision.reload.superseded_at

    chair = assign_chair
    sign_in chair
    patch finalize_epa_promotion_path(renewal), params: {
      recommendation: "approved", supervision_level_id: @decision_level.id,
      review_due_at: 6.months.from_now.to_date, notes: "Ketua panel mengesahkan target supervisi hasil tinjauan ulang."
    }

    renewed_decision = EntrustmentDecision.find_by!(epa_promotion: renewal)
    assert_equal "approved", renewal.reload.status
    assert_equal renewed_decision.id, old_decision.reload.superseded_by_id
    assert_nil renewed_decision.superseded_at
  end

  test "tinjauan ulang tidak dapat dimulai sebelum review_due_at" do
    @promotion.update!(status: "approved", reviewed_by: users(:dedi), reviewed_at: Time.current,
      finalized_by: users(:dedi), finalized_at: Time.current)
    decision = EntrustmentDecision.decide!(student: @student, epa: @promotion.epa, level: 3,
      justification: "Keputusan entrustment masih berada dalam masa berlaku review.",
      decided_by: users(:dedi), epa_promotion: @promotion, review_due_at: 2.days.from_now)
    sign_in users(:wati)

    assert_no_difference "EpaPromotion.count" do
      post request_epa_renewal_path(decision)
    end
    assert_nil decision.reload.superseded_at
  end

  test "dashboard EPA memisahkan kecukupan bukti dari keputusan dan menampilkan keragaman observasi" do
    other_scale = SupervisionScaleVersion.create!(code: "test_chen_same_label", name: "Skala Chen lokal",
      version_label: "2", use_case: "retrospective_observation")
    same_label_level = other_scale.supervision_levels.create!(ordinal: 3, code: "guided",
      label: "Dengan arahan", description: "Anchor instrumen ini memiliki definisi versi tersendiri.")
    EpaObservation.create!(student: @student, epa: @promotion.epa, observer: users(:budi),
      supervision_level: same_label_level, observed_at: 1.day.ago,
      narrative: "Observasi menggunakan skala kedua dengan anchor yang berbeda.", status: "recorded",
      submitted_at: Time.current)
    EpaObservation.create!(student: @student, epa: @promotion.epa, observer: users(:dedi),
      supervision_level: @promotion.epa.epa_observations.first.supervision_level, observed_at: Time.current,
      narrative: "Penanda keselamatan yang belum ditinjau tidak masuk tren kecukupan.", status: "recorded",
      submitted_at: Time.current, safety_flag: true)

    sign_in @student
    get epa_observations_path

    assert_response :success
    assert_match "Seluruh Syarat Bukti EPA terpenuhi", response.body
    assert_match "2/1", response.body
    assert_match "2 penilai berbeda", response.body
    assert_match "keputusan tetap melalui panel", response.body
    assert_match "EPA-P2 · Mengelola tindak lanjut klinis", response.body
    assert_match "Belum ada Syarat Bukti EPA aktif", response.body
    assert_match "Ottawa test · versi 1", response.body
    assert_match "Skala Chen lokal · versi 2", response.body
    assert_match "Tren supervisi pada versi skala ini", response.body
    assert_match "2 observasi", response.body
    assert_match "Perbandingan jejak observasi per siklus akademik", response.body
    assert_match "2026/2027 Ganjil", response.body
    assert_match "Flag keselamatan terbuka", response.body
  end

  test "pengajar tanpa penugasan tidak dapat membuka observasi EPA mahasiswa" do
    sign_in users(:budi)

    get epa_observations_path(student_id: @student.id)

    assert_redirected_to dashboard_path
  end

  test "conflict atau recusal tidak dihitung sebagai suara quorum" do
    study_programs(:profesi_dokter).update!(epa_panel_quorum: 1)
    @promotion.update!(status: "promoted", promoted_by: users(:wati), promoted_at: Time.current)
    sign_in users(:dedi)

    patch review_epa_promotion_path(@promotion), params: {
      recommendation: "approved", supervision_level_id: @decision_level.id,
      conflict_disclosed: "1", notes: "Saya memiliki relasi pribadi dengan mahasiswa ini."
    }

    review = @promotion.epa_promotion_reviews.find_by!(reviewer: users(:dedi))
    assert review.recused?
    assert review.conflict_disclosed?
    assert_equal "recusal", review.events.last.event_kind
    assert_nil @promotion.reload.quorum_reached_at
    assert_empty EntrustmentDecision.where(epa_promotion: @promotion)

    patch review_epa_promotion_path(@promotion), params: {
      recommendation: "approved", supervision_level_id: @decision_level.id,
      notes: "Saya mencoba menyampaikan suara setelah recusal ini."
    }
    assert review.reload.recused?
    assert_nil @promotion.reload.quorum_reached_at
  end

  test "keberatan membuat ronde baru dengan riwayat terpisah" do
    @promotion.update!(status: "approved", promoted_by: users(:wati), promoted_at: Time.current,
      finalized_by: users(:dedi), finalized_at: Time.current, reviewed_by: users(:dedi), reviewed_at: Time.current)
    EntrustmentDecision.decide!(student: @student, epa: @promotion.epa, level: @decision_level.ordinal,
      supervision_level: @decision_level, epa_promotion: @promotion,
      justification: "Keputusan awal panel untuk mahasiswa ini.", decided_by: users(:dedi))
    sign_in @student
    patch appeal_epa_promotion_path(@promotion), params: { reason: "Saya mengajukan bukti tambahan untuk ditinjau ulang." }

    appeal = @promotion.epa_promotion_appeals.sole
    assert_equal "appeal_pending", @promotion.reload.status
    assert_equal 2, @promotion.review_round
    assert_equal @student, appeal.appealed_by

    sign_in users(:dedi)
    patch review_epa_promotion_path(@promotion), params: {
      recommendation: "not_entrusted", notes: "Bukti tambahan belum cukup untuk kewenangan yang diminta."
    }
    assert_equal "appeal_pending", @promotion.reload.status
    assert_equal 1, @promotion.epa_promotion_reviews.where(round_number: 2).count
    chair = assign_chair
    sign_in chair
    patch finalize_epa_promotion_path(@promotion), params: {
      recommendation: "not_entrusted", notes: "Keberatan ditelaah; bukti tambahan belum cukup untuk entrustment."
    }
    assert_equal "not_entrusted", @promotion.reload.status
    assert_equal "not_entrusted", appeal.reload.resolution
    assert appeal.resolved_at
    assert_raises(ActiveRecord::ReadOnlyRecord) { appeal.destroy! }
  end

  private

  def assign_chair
    chair = User.create!(full_name: "Ketua Panel EPA", email: "chair-#{SecureRandom.hex(4)}@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: study_programs(:profesi_dokter))
    chair.roles << roles(:kaprodi)
    UserAssignment.create!(user: chair, assigned_by: users(:dedi), study_program: study_programs(:profesi_dokter),
      assignment_role: "epa_panel_chair", scope_type: "User", scope_id: @student.id,
      reason: "Ditunjuk sebagai ketua panel EPA untuk mahasiswa ini.")
    chair
  end
end
