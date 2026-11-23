require "test_helper"

class EvaluationScheduleTest < ActiveSupport::TestCase
  test "jadwal DOPS dapat ditautkan ke Event Asesmen DOPS pada prodi mahasiswa" do
    event = AssessmentEvent.create!(name: "DOPS klinis", assessment_type: "dops",
      academic_period: academic_periods(:current_period), study_program: study_programs(:sarjana_kedokteran),
      status: "published", max_score: 100)

    schedule = EvaluationSchedule.create!(kind: "dops", student: users(:siti), assessment_event: event,
      scheduled_at: 2.days.from_now)

    assert_equal event, schedule.reload.assessment_event
  end

  test "jadwal menolak Event Asesmen yang jenisnya tidak cocok" do
    event = AssessmentEvent.create!(name: "Mini-CEX", assessment_type: "mini_cex",
      academic_period: academic_periods(:current_period), study_program: study_programs(:sarjana_kedokteran),
      status: "published", max_score: 100)
    schedule = EvaluationSchedule.new(kind: "dops", student: users(:siti), assessment_event: event,
      scheduled_at: 2.days.from_now)

    assert_not schedule.valid?
    assert_includes schedule.errors[:assessment_event], "harus bertipe DOPS"
  end

  test "jadwal baru wajib tertaut ke Event Asesmen" do
    schedule = EvaluationSchedule.new(kind: "dops", student: users(:siti), scheduled_at: 2.days.from_now)

    assert_not schedule.valid?
    assert_includes schedule.errors[:assessment_event], "wajib dipilih dari Event Asesmen"
  end
end
