require "test_helper"

class EpaPromotionReadinessTest < ActiveSupport::TestCase
  setup do
    @student = User.create!(full_name: "Mahasiswa Profesi", email: "profesi@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: study_programs(:profesi_dokter))
    @student.roles << roles(:mahasiswa)
    @preceptor = users(:wati)
    @framework = CompetencyFramework.create!(study_program: study_programs(:profesi_dokter),
      name: "Framework EPA Test", version: "90", education_stage: "professional")
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

  private

  def build_observation(safety_flag: false)
    EpaObservation.new(student: @student, epa: @epa, observer: @preceptor,
      supervision_level: @level, observed_at: Time.current, narrative: "Mengumpulkan informasi dan menyusun rencana dengan supervisi.",
      status: "recorded", submitted_at: Time.current, safety_flag: safety_flag)
  end
end
