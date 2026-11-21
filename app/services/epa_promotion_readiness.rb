# frozen_string_literal: true

# A readiness flag is evidence sufficiency only. It never creates an
# entrustment decision or implies that the learner has been entrusted.
class EpaPromotionReadiness
  Result = Data.define(:eligible, :requirements, :reasons)

  def initialize(student:, epa:)
    @student = student
    @epa = epa
  end

  def call
    return Result.new(false, [], ["EPA tidak berlaku untuk jenjang Sarjana"]) unless applicable?

    requirements = @epa.evidence_requirements.where(status: "active").to_a
    gating_requirements = requirements.select do |requirement|
      requirement.is_mandatory? || (requirement.fulfillment_rule || {}).fetch("critical", false)
    end
    reasons = []
    reasons << "belum ada Syarat Bukti EPA wajib atau kritis yang aktif" if gating_requirements.empty?
    gating_requirements.each do |requirement|
      progress = EvidenceRequirementProgress.new(requirement).call
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
      @epa.competency_framework.education_stage.in?(%w[professional specialist subspecialist]) &&
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
