require "test_helper"

class EpaPromotionReadinessTest < ActiveSupport::TestCase
  setup do
    @student = User.create!(full_name: "Mahasiswa Profesi", email: "profesi@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: study_programs(:profesi_dokter))
    @student.roles << roles(:mahasiswa)
    @preceptor = users(:wati)
    @framework = CompetencyFramework.create!(study_program: study_programs(:profesi_dokter),
      name: "Framework EPA Test", version: "90", education_stage: "profesi")
    @domain = @framework.competency_items.create!(title: "Kompetensi klinis", code: "D-01", level_type: "domain")
    @epa = @framework.epas.create!(code: "EPA-T1", title: "Menangani pasien dengan masalah umum")
    @requirement = EvidenceRequirement.create!(epa: @epa, origin: "manual", source_type: "epa_observation",
      required_count: 1, fulfillment_rule: { "minimum_distinct_assessors" => 1, "minimum_distinct_dates" => 1 })
    @framework.publish!
    @epa.reload
    @scale = SupervisionScaleVersion.create!(code: "test_ottawa", name: "Skala observasi uji", version_label: "1",
      use_case: "retrospective_observation")
    @level = @scale.supervision_levels.create!(ordinal: 2, code: "guided", label: "Dengan arahan",
      description: "Supervisor memberi arahan.")
    ClinicalRotation.create!(user: @student, preceptor: @preceptor, academic_period: academic_periods(:current_period),
      station_name: "Rotasi Uji", start_date: 2.days.ago.to_date, end_date: 5.days.from_now.to_date)
  end

  test "observasi memenuhi aturan keragaman dan memberi preseptor penanda serta notifikasi satu kali" do
    observation = build_observation

    assert_difference "EvidenceRecord.count", 1 do
      observation.save!
    end

    promotion = EpaPromotion.find_by!(student: @student, epa: @epa)
    assert_equal "ready", promotion.status
    assert_equal 1, Notification.where(recipient: @preceptor, notifiable: promotion,
      notification_type: "epa_promotion_ready").count
    assert_equal :fulfilled, EvidenceRequirementProgress.new(@requirement).call.status
  end

  test "observasi dengan flag keselamatan tidak membuat promosi" do
    observation = build_observation(safety_flag: true)
    observation.save!

    assert_not EpaPromotion.exists?(student: @student, epa: @epa)
    assert_not Notification.exists?(recipient: @preceptor, notification_type: "epa_promotion_ready")

    observation.resolve_safety!(by: users(:budi), resolution: "Risiko ditinjau dan tindak lanjut pendidikan disepakati.")
    assert EpaPromotion.exists?(student: @student, epa: @epa, status: "ready")
  end

  test "kecukupan EPA dapat dinilai pada jenjang Sarjana" do
    student = User.create!(full_name: "Mahasiswa Sarjana EPA", email: "sarjana-epa@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: study_programs(:sarjana_kedokteran))
    student.roles << roles(:mahasiswa)
    ModuleConfiguration.for(student.study_program).update!({ epa: "1" }, actor: users(:dedi))
    framework = CompetencyFramework.create!(study_program: student.study_program,
      name: "Framework EPA Sarjana", version: "1", education_stage: "sarjana")
    framework.competency_items.create!(title: "Kompetensi klinis sarjana", code: "S1-D1", level_type: "domain")
    epa = framework.epas.create!(code: "EPA-S1", title: "Mengumpulkan informasi klinis", status: "draft")
    framework.publish!

    result = EpaPromotionReadiness.new(student: student, epa: epa.reload).call

    assert_not_includes result.reasons, "EPA tidak berlaku untuk jenjang Sarjana"
    assert_includes result.reasons, "belum ada Bukti yang Diharapkan untuk EPA yang wajib atau kritis"
  end

  test "active entrustment prevents duplicate promotion readiness" do
    EntrustmentDecision.decide!(student: @student, epa: @epa, level: 2,
      justification: "Keputusan entrustment sudah ditetapkan oleh akademik.", decided_by: users(:dedi))

    result = EpaPromotionReadiness.new(student: @student, epa: @epa).call

    assert_not result.eligible
    assert_includes result.reasons, "sudah ada keputusan entrustment aktif; tinjau atau cabut melalui workflow panel sebelum promosi baru"
  end

  test "pengingat tinjauan keputusan EPA dikirim sekali ke mahasiswa dan pihak yang relevan" do
    decision = EntrustmentDecision.decide!(student: @student, epa: @epa, level: 2,
      justification: "Keputusan perlu ditinjau setelah masa praktik berikutnya.", decided_by: users(:dedi),
      review_due_at: 1.day.ago)

    assert_difference "Notification.count", 3 do
      EpaEntrustmentReviewDueJob.perform_now
    end

    assert_equal Time.current.to_date, decision.reload.review_due_notified_at.to_date
    assert_equal 3, Notification.where(notifiable: decision, notification_type: "epa_entrustment_review_due").count
    assert Notification.exists?(recipient: @student, notifiable: decision, notification_type: "epa_entrustment_review_due")
    assert Notification.exists?(recipient: @preceptor, notifiable: decision, notification_type: "epa_entrustment_review_due")
    assert Notification.exists?(recipient: users(:dedi), notifiable: decision, notification_type: "epa_entrustment_review_due")

    assert_no_difference "Notification.count" do
      EpaEntrustmentReviewDueJob.perform_now
    end
  end

  test "pengingat tidak dikirim sebelum tanggal tinjauan atau setelah keputusan digantikan" do
    future = EntrustmentDecision.decide!(student: @student, epa: @epa, level: 2,
      justification: "Keputusan akan ditinjau pada tanggal yang telah ditentukan.", decided_by: users(:dedi),
      review_due_at: 1.day.from_now)

    assert_no_difference "Notification.count" do
      EpaEntrustmentReviewDueJob.perform_now
    end

    past = EntrustmentDecision.decide!(student: @student, epa: @epa, level: 3,
      justification: "Keputusan baru menggantikan keputusan lama untuk EPA ini.", decided_by: users(:dedi),
      review_due_at: 1.day.ago)
    assert future.reload.superseded_at
    assert_difference "Notification.count", 3 do
      EpaEntrustmentReviewDueJob.perform_now
    end
    assert_not past.reload.superseded_at
  end

  private

  def build_observation(safety_flag: false)
    EpaObservation.new(student: @student, epa: @epa, observer: @preceptor,
      supervision_level: @level, observed_at: Time.current, narrative: "Mengumpulkan informasi dan menyusun rencana dengan supervisi.",
      status: "recorded", submitted_at: Time.current, safety_flag: safety_flag)
  end
end
