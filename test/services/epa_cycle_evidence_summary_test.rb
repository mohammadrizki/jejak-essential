require "test_helper"

class EpaCycleEvidenceSummaryTest < ActiveSupport::TestCase
  test "summarizes coverage by rotation period without counting unresolved safety observations as valid" do
    student = User.create!(full_name: "Mahasiswa Siklus EPA", email: "epa-cycle-summary@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current, study_program: study_programs(:profesi_dokter))
    student.roles << roles(:mahasiswa)
    framework = CompetencyFramework.create!(study_program: student.study_program,
      name: "Framework Siklus EPA", version: "1", education_stage: "professional")
    framework.competency_items.create!(title: "Kompetensi klinis", code: "D-CYCLE", level_type: "domain")
    epa = framework.epas.create!(code: "EPA-CYCLE", title: "Menangani pasien dengan supervisi")
    framework.publish!
    epa.reload

    past_period = AcademicPeriod.create!(name: "2025/2026 Genap", start_date: 9.months.ago.to_date,
      end_date: 5.months.ago.to_date)
    current_period = academic_periods(:current_period)
    future_period = AcademicPeriod.create!(name: "2027/2028 Ganjil", start_date: 7.months.from_now.to_date,
      end_date: 11.months.from_now.to_date)
    past_rotation = ClinicalRotation.create!(user: student, academic_period: past_period,
      station_name: "Rotasi Lama", start_date: 8.months.ago.to_date, end_date: 6.months.ago.to_date)
    current_rotation = ClinicalRotation.create!(user: student, academic_period: current_period,
      station_name: "Rotasi Kini", start_date: 10.days.ago.to_date, end_date: 10.days.from_now.to_date)
    ClinicalRotation.create!(user: student, academic_period: future_period,
      station_name: "Rotasi Mendatang", start_date: 8.months.from_now.to_date, end_date: 10.months.from_now.to_date)
    scale = SupervisionScaleVersion.create!(code: "epa_cycle_summary", name: "Skala observasi siklus",
      version_label: "1", use_case: "retrospective_observation")
    level = scale.supervision_levels.create!(ordinal: 2, code: "guided", label: "Dengan supervisi",
      description: "Supervisor mendampingi aktivitas.")

    EpaObservation.create!(student: student, epa: epa, observer: users(:wati), clinical_rotation: past_rotation,
      supervision_level: level, observed_at: 7.months.ago, narrative: "Observasi pada rotasi sebelumnya.",
      status: "recorded", submitted_at: 7.months.ago)
    EpaObservation.create!(student: student, epa: epa, observer: users(:budi), clinical_rotation: current_rotation,
      supervision_level: level, observed_at: 2.days.ago, narrative: "Observasi dengan isu keselamatan.",
      safety_flag: true, status: "recorded", submitted_at: 2.days.ago)
    EpaObservation.create!(student: student, epa: epa, observer: users(:wati), clinical_rotation: current_rotation,
      supervision_level: level, observed_at: 1.day.ago, narrative: "Observasi yang layak dihitung.",
      status: "recorded", submitted_at: 1.day.ago)

    summaries = EpaCycleEvidenceSummary.new(student: student, epa: epa).call.index_by(&:academic_period)

    assert_equal 1, summaries.fetch(past_period).valid_observations.size
    assert_equal 1, summaries.fetch(past_period).assessor_count
    assert_equal 2, summaries.fetch(current_period).observations.size
    assert_equal 1, summaries.fetch(current_period).valid_observations.size
    assert_equal 1, summaries.fetch(current_period).unresolved_safety_count
    assert_empty summaries.fetch(future_period).observations
    assert_equal 0, summaries.fetch(future_period).assessor_count
  end
end
