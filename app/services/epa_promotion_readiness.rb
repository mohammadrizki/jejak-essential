# frozen_string_literal: true

# A readiness flag is evidence sufficiency only. It never creates an
# entrustment decision or implies that the learner has been entrusted.
class EpaPromotionReadiness
  Result = Data.define(:eligible, :requirements, :reasons)

  def initialize(student:, epa:)
    @student = student
    @epa = epa
  end

  def call(allow_current_decision: false)
    return Result.new(false, [], ["EPA tidak aktif atau tidak berlaku pada program studi ini"]) unless applicable?

    requirements = @epa.evidence_requirements.where(status: "active").to_a
    if !allow_current_decision && EntrustmentDecision.current.exists?(student: @student, epa: @epa)
      return Result.new(false, requirements, ["sudah ada keputusan entrustment aktif; tinjau atau cabut melalui workflow panel sebelum promosi baru"])
    end
    progress_by_requirement = requirements.index_with do |requirement|
      EvidenceRequirementProgress.new(requirement, student: @student).call
    end
    gating_requirements = requirements.select do |requirement|
      version = progress_by_requirement.fetch(requirement).requirement_version
      configuration = version&.configuration || requirement.configuration_snapshot
      configuration.fetch("is_mandatory", requirement.is_mandatory?) ||
        configuration.dig("fulfillment_rule", "critical")
    end
    reasons = []
    reasons << "belum ada Syarat Bukti EPA wajib atau kritis yang aktif" if gating_requirements.empty?
    gating_requirements.each do |requirement|
      progress = progress_by_requirement.fetch(requirement)
      reasons << "Syarat Bukti ##{requirement.id} belum terpenuhi" unless progress.status == :fulfilled
    end
    flagged = @student.epa_observations.where(epa: @epa, safety_flag: true, status: %w[submitted recorded], safety_resolved_at: nil).exists?
    reasons << "ada penanda keselamatan yang belum ditindaklanjuti Otoritas Akademik" if flagged
    Result.new(reasons.empty?, requirements, reasons)
  end

  def promote_if_eligible!
    result = call
    return unless result.eligible

    promotion = EpaPromotion.open.find_by(student: @student, epa: @epa)
    return promotion if promotion

    promotion = EpaPromotion.create!(student: @student, epa: @epa, status: "ready", eligible_at: Time.current)
    notify_preceptors!(promotion)
    promotion
  rescue ActiveRecord::RecordNotUnique
    EpaPromotion.open.find_by!(student: @student, epa: @epa)
  end

  private

  def applicable?
    @student.study_program_id.present? &&
      ModuleConfiguration.for(@student.study_program).enabled?("epa") &&
      @epa.competency_framework.study_program_id == @student.study_program_id &&
      @epa.competency_framework.education_stage.in?(%w[undergraduate professional specialist subspecialist]) &&
      @epa.competency_framework.status == "published" && @epa.status == "published"
  end

  def notify_preceptors!(promotion)
    preceptors = @student.clinical_rotations.ongoing.where.not(preceptor_id: nil).includes(:preceptor).map(&:preceptor).compact.uniq
    preceptors.each do |preceptor|
      Notification.notify!(
        recipient: preceptor,
        title: "EPA siap diajukan ke Otoritas Akademik",
        message: "#{@student.full_name} memenuhi kecukupan bukti untuk #{@epa.code} — #{@epa.title}. Tinjau dossier sebelum mengajukan promosi.",
        notifiable: promotion,
        notification_type: "epa_promotion_ready"
      )
    end
  end
end
