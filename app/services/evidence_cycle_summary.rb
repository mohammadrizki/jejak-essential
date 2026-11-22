# frozen_string_literal: true

# Shows evidence sufficiency by academic cycle without treating it as a
# competency decision. Each cycle uses the learner's established requirement
# version, or the latest version that existed by that cycle's end.
class EvidenceCycleSummary
  Cycle = Data.define(:academic_period, :requirement_count, :fulfilled_count,
    :in_progress_count, :not_started_count, :critical_gap_count, :requirements)

  def initialize(student:, framework:, periods: nil)
    @student = student
    @framework = framework
    @periods = periods
  end

  def call
    periods = (@periods || AcademicPeriod.ordered.to_a)
      .select { |period| period.start_date <= Date.current }
      .sort_by { |period| [period.start_date, period.id] }
    requirements = framework_requirements.includes(:versions, :evidence_records).to_a

    periods.map { |period| summarize(period, requirements) }
  end

  private

  def framework_requirements
    item_ids = @framework.competency_items.select(:id)
    indicator_ids = @framework.competency_indicators.select(:id)
    epa_ids = @framework.epas.select(:id)
    scope = EvidenceRequirement.where(status: "active", competency_item_id: item_ids)
      .or(EvidenceRequirement.where(status: "active", competency_indicator_id: indicator_ids))
      .or(EvidenceRequirement.where(status: "active", epa_id: epa_ids))
    scope.distinct
  end

  def summarize(period, requirements)
    range = period.start_date..[period.end_date, Date.current].min
    entries = requirements.filter_map do |requirement|
      version = version_for(requirement, period)
      next unless version&.status == "active"

      progress = EvidenceRequirementProgress.new(requirement, student: @student,
        evidence_date_range: range, requirement_version: version).call
      configuration = version.configuration
      {
        requirement: requirement,
        progress: progress,
        critical: configuration.fetch("is_mandatory", false) || configuration.dig("fulfillment_rule", "critical") == true
      }
    end

    fulfilled = entries.count { |entry| entry[:progress].status == :fulfilled }
    in_progress = entries.count { |entry| entry[:progress].status == :in_progress }
    not_started = entries.count { |entry| entry[:progress].status == :not_started }
    critical_gap = entries.count { |entry| entry[:critical] && entry[:progress].status != :fulfilled }
    Cycle.new(academic_period: period, requirement_count: entries.size, fulfilled_count: fulfilled,
      in_progress_count: in_progress, not_started_count: not_started,
      critical_gap_count: critical_gap, requirements: entries)
  end

  def version_for(requirement, period)
    cutoff = period.end_date.end_of_day
    student_versions = requirement.evidence_records.filter_map do |record|
      next unless record.student&.id == @student.id

      record.evidence_requirement_version
    end.uniq(&:id).select { |version| version.created_at <= cutoff }
    return student_versions.min_by(&:version) if student_versions.any?

    requirement.versions.select { |version| version.created_at <= cutoff }.max_by(&:version)
  end
end
