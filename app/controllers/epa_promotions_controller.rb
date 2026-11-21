# frozen_string_literal: true

class EpaPromotionsController < ApplicationController
  before_action :authenticate_user!

  def index
    @promotions = visible_promotions.includes(:student, :epa, :promoted_by).order(eligible_at: :desc)
    @readiness = @promotions.index_with do |promotion|
      EpaPromotionReadiness.new(student: promotion.student, epa: promotion.epa).call
    end
  end

  def promote
    promotion = EpaPromotion.open.find(params[:id])
    return deny_access unless current_user.can_view_student?(promotion.student) && preceptor_for?(promotion.student)
    return redirect_to epa_promotions_path, alert: "Kecukupan bukti atau tindak lanjut keselamatan berubah; promosi ditahan." unless
      EpaPromotionReadiness.new(student: promotion.student, epa: promotion.epa).call.eligible

    promotion.promote!(by: current_user)
    Notification.notify!(recipient: promotion.student, sender: current_user, notifiable: promotion,
      title: "EPA diajukan ke Otoritas Akademik", message: "#{promotion.epa.code} — #{promotion.epa.title}")
    redirect_to epa_promotions_path, notice: "Dossier EPA diajukan ke Otoritas Akademik."
  end

  def review
    promotion = EpaPromotion.find(params[:id])
    return deny_access unless academic_authority_for?(promotion.student)
    return redirect_to epa_promotions_path, alert: "Pengajuan belum dipromosikan oleh preseptor." unless promotion.status.in?(%w[promoted under_review])

    recommendation = params[:recommendation].to_s
    return redirect_to epa_promotions_path, alert: "Rekomendasi panel tidak dikenal." unless EpaPromotionReview::RECOMMENDATIONS.include?(recommendation)

    EntrustmentDecision.transaction do
      level = SupervisionLevel.find(params[:supervision_level_id]) if recommendation == "approved"
      review = promotion.epa_promotion_reviews.find_or_initialize_by(reviewer: current_user)
      review.update!(recommendation: recommendation, supervision_level: level, notes: params[:notes].to_s)
      quorum = committee_quorum_for(promotion.student)
      matching_reviews = promotion.epa_promotion_reviews.where(recommendation: recommendation)
      matching_reviews = matching_reviews.where(supervision_level: level) if recommendation == "approved"
      if matching_reviews.count >= quorum
        promotion.update!(status: recommendation, reviewed_by: current_user, reviewed_at: Time.current,
                          notes: "Konsensus panel #{matching_reviews.count}/#{quorum}: #{params[:notes]}")
      else
        promotion.update!(status: "under_review", reviewed_by: current_user, reviewed_at: Time.current,
                          notes: "Menunggu konsensus panel (#{matching_reviews.count}/#{quorum}).")
      end
      if promotion.status == "approved"
        EntrustmentDecision.decide!(student: promotion.student, epa: promotion.epa, level: level.ordinal,
          supervision_level: level, epa_promotion: promotion, justification: params[:notes].to_s,
          decided_by: current_user)
      end
    end
    Notification.notify!(recipient: promotion.student, sender: current_user, notifiable: promotion,
      title: promotion.status == "approved" ? "Keputusan panel EPA disahkan" : "Tinjauan panel EPA diperbarui",
      message: "#{promotion.epa.code} — #{promotion.status.humanize}: #{promotion.notes}")
    redirect_to epa_promotions_path, notice: promotion.status == "approved" ?
      "Konsensus panel tercapai; keputusan entrustment disahkan." :
      "Rekomendasi panel tersimpan; konsensus belum tercapai."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => error
    redirect_to epa_promotions_path, alert: error.message
  end

  private

  def visible_promotions
    scope = EpaPromotion.where(status: %w[ready promoted under_review needs_more_evidence])
    return scope if current_user.has_role?("admin")
    return scope.joins(:student).where(users: { study_program_id: current_user.study_program_id }) if current_user.has_role?("kaprodi")
    return scope.joins(student: :clinical_rotations)
      .where(clinical_rotations: { preceptor_id: current_user.id })
      .where("clinical_rotations.start_date <= ? AND clinical_rotations.end_date >= ?", Date.current, Date.current).distinct if current_user.has_role?("preseptor")

    EpaPromotion.none
  end

  def preceptor_for?(student)
    current_user.has_role?("admin") || student.clinical_rotations.ongoing.exists?(preceptor: current_user)
  end

  def academic_authority_for?(student)
    current_user.has_role?("admin") || (current_user.has_role?("kaprodi") && current_user.study_program_id == student.study_program_id)
  end

  def committee_quorum_for(student)
    members = User.active_accounts.joins(:roles).where(roles: { code: "kaprodi" },
      study_program_id: student.study_program_id).distinct.count
    return 1 if members.zero? && current_user.has_role?("admin")

    [members, 2].min
  end

  def deny_access
    redirect_to dashboard_path, alert: "Anda tidak memiliki kewenangan untuk tindakan EPA ini."
  end
end
