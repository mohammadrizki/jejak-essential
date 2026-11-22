# frozen_string_literal: true

# Descriptive comparison of EPA observations by the academic period attached
# to the student's clinical rotation. It reports coverage and diversity only;
# it does not infer sufficiency, compare ordinals across scale versions, or
# produce an entrustment recommendation.
class EpaCycleEvidenceSummary
  Cycle = Struct.new(:academic_period, :observations, :valid_observations,
    :assessor_count, :case_count, :opportunity_count, :unresolved_safety_count,
    keyword_init: true) do
    def period_label = academic_period&.name || "Periode rotasi tidak tercatat"
  end

  def initialize(student:, epa:, observations: nil, rotations: nil)
    @student = student
    @epa = epa
    @observations = observations
    @rotations = rotations
  end

  def call
    rotations = @rotations || @student.clinical_rotations.includes(:academic_period).to_a
    observations = @observations || EpaObservation.where(student: @student, epa: @epa)
      .includes(:observer, :clinical_case, :clinical_rotation, :supervision_level)
      .chronological.to_a

    periods = rotations.filter_map(&:academic_period).uniq
    observations = observations.select { |observation| observation.epa_id == @epa.id }
    grouped = observations.group_by { |observation| observation.clinical_rotation&.academic_period }
    periods.each { |period| grouped[period] ||= [] }

    grouped.map { |period, rows| build_cycle(period, rows) }
      .sort_by { |cycle| [cycle.academic_period&.start_date || Date.new(1), cycle.period_label] }
  end

  private

  def build_cycle(period, observations)
    valid = observations.select do |observation|
      observation.status == "recorded" && (!observation.safety_flag? || observation.safety_resolved_at.present?)
    end

    Cycle.new(
      academic_period: period,
      observations: observations,
      valid_observations: valid,
      assessor_count: valid.map(&:observer_id).uniq.size,
      case_count: valid.filter_map(&:clinical_case_id).uniq.size,
      opportunity_count: valid.map { |observation| observation.observed_at.to_date }.uniq.size,
      unresolved_safety_count: observations.count { |observation| observation.safety_flag? && observation.safety_resolved_at.blank? }
    )
  end
end
