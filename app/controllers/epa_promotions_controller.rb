# frozen_string_literal: true

class EpaPromotionsController < ApplicationController
  before_action :authenticate_user!

  def index
    @promotions = visible_promotions.includes(:student, :epa, :promoted_by).order(eligible_at: :desc)
    @readiness = @promotions.index_with do |promotion|
      EpaPromotionReadiness.new(student: promotion.student, epa: promotion.epa)
        .call(allow_current_decision: promotion.renewal_of_decision_id.present?)
    end
    @current_decisions = EntrustmentDecision.current.where(student_id: @promotions.map(&:student_id).uniq,
      epa_id: @promotions.map(&:epa_id).uniq).includes(:supervision_level).index_by { |decision| [decision.student_id, decision.epa_id] }
    @chair_recommendations = @promotions.index_with do |promotion|
      ids = AssignmentAuthorization.panel_member_ids(student: promotion.student, promotion: promotion)
      promotion.epa_promotion_reviews.where(round_number: promotion.review_round, reviewer_id: ids, recused_at: nil)
        .includes(:supervision_level).group_by { |review| [review.recommendation, review.supervision_level_id] }
        .filter_map do |(recommendation, supervision_level_id), reviews|
          next if reviews.size < committee_quorum_for(promotion)

          { recommendation: recommendation, supervision_level_id: supervision_level_id,
            label: [recommendation.humanize, reviews.first.supervision_level&.label].compact.join(" · "), count: reviews.size }
        end
    end
  end

  def request_renewal
    decision = EntrustmentDecision.current.includes(:student, :epa).find(params[:decision_id])
    return module_disabled unless ModuleConfiguration.for(decision.student.study_program).enabled?("epa")
    return deny_access unless current_user.has_role?("preseptor") && preceptor_for?(decision.student)
    return redirect_to epa_promotions_path, alert: "Tanggal tinjauan ulang keputusan ini belum jatuh tempo." unless decision.review_due?

    promotion = EpaPromotion.request_renewal!(decision: decision, by: current_user)
    panel_recipients_for(promotion).each do |reviewer|
      Notification.notify!(recipient: reviewer, sender: current_user, notifiable: promotion,
        title: "Tinjauan ulang EPA diajukan", message: "#{promotion.epa.code} — #{promotion.student.full_name}; keputusan lama tetap aktif sampai panel mengesahkan keputusan baru.")
    end
    Notification.notify!(recipient: decision.student, sender: current_user, notifiable: promotion,
      title: "Tinjauan ulang EPA dimulai", message: "Keputusan #{decision.epa.code} memasuki tinjauan panel; keputusan lama tetap berlaku sampai ada keputusan baru.")
    redirect_to epa_promotions_path, notice: "Tinjauan ulang EPA diajukan ke panel. Keputusan aktif tidak berubah sebelum pengesahan baru."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, ActiveRecord::RecordNotUnique, ArgumentError => error
    redirect_to epa_promotions_path, alert: error.message
  end

  def promote
    promotion = EpaPromotion.open.find(params[:id])
    return module_disabled unless ModuleConfiguration.for(promotion.student.study_program).enabled?("epa")
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
    return module_disabled unless ModuleConfiguration.for(promotion.student.study_program).enabled?("epa")
    return deny_access unless academic_authority_for?(promotion)
    recommendation = params[:recommendation].to_s
    return redirect_to epa_promotions_path, alert: "Rekomendasi panel tidak dikenal." unless EpaPromotionReview::RECOMMENDATIONS.include?(recommendation)
    conflict_disclosed = ActiveModel::Type::Boolean.new.cast(params[:conflict_disclosed]) == true
    recusal_requested = ActiveModel::Type::Boolean.new.cast(params[:recuse]) || conflict_disclosed
    recusal_reason = params[:recusal_reason].presence || params[:notes]
    if recusal_requested && recusal_reason.to_s.strip.length < 10
      return redirect_to epa_promotions_path, alert: "Alasan recusal/conflict minimal 10 karakter."
    end
    active_decision = promotion.status.in?(%w[approved restricted]) &&
      EntrustmentDecision.current.exists?(student: promotion.student, epa: promotion.epa)
    unless promotion.status.in?(%w[promoted under_review appeal_pending]) || (active_decision && recommendation == "revoked")
      return redirect_to epa_promotions_path, alert: "Status dossier ini tidak menerima rekomendasi panel tersebut."
    end
    existing_review = promotion.epa_promotion_reviews.find_by(reviewer: current_user, round_number: promotion.review_round)
    if existing_review&.recused? && !recusal_requested
      return redirect_to epa_promotions_path, alert: "Recusal pada ronde ini bersifat tetap; Anda tidak dapat memberikan suara setelah menyatakan konflik."
    end
    quorum_was_reached = promotion.quorum_reached_at.present?

    EntrustmentDecision.transaction do
      review = promotion.epa_promotion_reviews.find_or_initialize_by(reviewer: current_user, round_number: promotion.review_round)
      if recusal_requested
        reason = recusal_reason.to_s.strip
        review.update!(recommendation: "deferred", supervision_level: nil, notes: reason,
          conflict_disclosed: true, recused_at: Time.current, recusal_reason: reason)
        review.events.create!(event_kind: "recusal", recommendation: nil, conflict_disclosed: true,
          notes: reason, recorded_at: Time.current)
        promotion.update!(status: promotion.status == "appeal_pending" ? "appeal_pending" : "under_review",
          quorum_reached_at: nil)
        next
      end

      level = SupervisionLevel.find(params[:supervision_level_id]) if recommendation.in?(%w[approved restricted])
      review.update!(recommendation: recommendation, supervision_level: level, notes: params[:notes].to_s,
        conflict_disclosed: conflict_disclosed, recused_at: nil, recusal_reason: nil)
      review.events.create!(event_kind: "recommendation", recommendation: recommendation,
        supervision_level: level, conflict_disclosed: conflict_disclosed,
        notes: params[:notes].to_s, recorded_at: Time.current)
      quorum = committee_quorum_for(promotion)
      panel_member_ids = AssignmentAuthorization.panel_member_ids(student: promotion.student, promotion: promotion)
      active_reviews = promotion.epa_promotion_reviews.where(round_number: promotion.review_round,
        reviewer_id: panel_member_ids, recused_at: nil)
      matching_reviews = active_reviews.where(recommendation: recommendation)
      matching_reviews = matching_reviews.where(supervision_level: level) if recommendation.in?(%w[approved restricted])
      quorum_reached = matching_reviews.count >= quorum
      next_status = promotion.status == "appeal_pending" ? "appeal_pending" : "under_review"
      promotion.update!(status: next_status, quorum_reached_at: quorum_reached ? (promotion.quorum_reached_at || Time.current) : nil,
        dossier_snapshot: promotion.dossier_snapshot.presence || CompetencyAttainmentSnapshot.capture_epa_dossier(student: promotion.student, epa: promotion.epa),
        notes: quorum_reached ? "Rekomendasi panel #{recommendation} mencapai quorum #{matching_reviews.count}/#{quorum}; menunggu pengesahan ketua panel." :
          "Rekomendasi tersimpan; quorum #{matching_reviews.count}/#{quorum}.")
    end
    Notification.notify!(recipient: promotion.student, sender: current_user, notifiable: promotion,
      title: "Tinjauan panel EPA diperbarui",
      message: "#{promotion.epa.code} — #{promotion.status.humanize}: #{promotion.notes}")
    if promotion.quorum_reached_at.present? && !quorum_was_reached
      panel_chairs_for(promotion).each do |chair|
        Notification.notify!(recipient: chair, sender: current_user, notifiable: promotion,
          title: "Dossier EPA siap disahkan", message: "#{promotion.epa.code} mencapai quorum panel untuk #{promotion.student.full_name}.")
      end
    end
    redirect_to epa_promotions_path, notice: promotion.quorum_reached_at.present? ?
      "Quorum tercapai. Keputusan menunggu pengesahan ketua panel." : "Rekomendasi panel tersimpan; quorum belum tercapai."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => error
    redirect_to epa_promotions_path, alert: error.message
  end

  def finalize
    promotion = EpaPromotion.find(params[:id])
    return module_disabled unless ModuleConfiguration.for(promotion.student.study_program).enabled?("epa")
    return deny_access unless chair_for?(promotion)
    return redirect_to epa_promotions_path, alert: "Dossier tidak berada pada tahap yang dapat disahkan." unless promotion.status.in?(%w[under_review appeal_pending])
    return redirect_to epa_promotions_path, alert: "Dossier belum mencapai quorum." unless promotion.quorum_reached_at.present?

    recommendation = params[:recommendation].to_s
    return redirect_to epa_promotions_path, alert: "Rekomendasi panel tidak dikenal." unless EpaPromotionReview::RECOMMENDATIONS.include?(recommendation)
    return redirect_to epa_promotions_path, alert: "Catatan pengesahan minimal 10 karakter." if params[:notes].to_s.strip.length < 10
    level = SupervisionLevel.find(params[:supervision_level_id]) if recommendation.in?(%w[approved restricted])
    quorum = committee_quorum_for(promotion)
    member_ids = AssignmentAuthorization.panel_member_ids(student: promotion.student, promotion: promotion)
    matches = promotion.epa_promotion_reviews.where(round_number: promotion.review_round, reviewer_id: member_ids, recused_at: nil,
      recommendation: recommendation)
    matches = matches.where(supervision_level: level) if recommendation.in?(%w[approved restricted])
    return redirect_to epa_promotions_path, alert: "Rekomendasi terpilih tidak memperoleh quorum." if matches.count < quorum

    EntrustmentDecision.transaction do
      promotion.update!(status: recommendation, finalized_by: current_user, finalized_at: Time.current,
        reviewed_by: current_user, reviewed_at: Time.current,
        review_due_at: params[:review_due_at].presence,
        notes: "Pengesahan ketua panel atas rekomendasi quorum #{recommendation}. #{params[:notes]}".strip)
      if recommendation.in?(%w[approved restricted])
        EntrustmentDecision.decide!(student: promotion.student, epa: promotion.epa, level: level.ordinal,
          supervision_level: level, epa_promotion: promotion, review_due_at: promotion.review_due_at,
          justification: promotion.notes, decided_by: current_user)
      elsif recommendation.in?(%w[revoked not_entrusted])
        EntrustmentDecision.revoke_for_epa!(student: promotion.student, epa: promotion.epa,
          reason: params[:notes].to_s, by: current_user, promotion: promotion)
      end
      appeal = promotion.epa_promotion_appeals.find_by(round_number: promotion.review_round)
      appeal&.resolve!(by: current_user, resolution: recommendation, notes: params[:notes])
    end
    Notification.notify!(recipient: promotion.student, sender: current_user, notifiable: promotion,
      title: "Ketua panel mengesahkan keputusan EPA", message: "#{promotion.epa.code} — #{promotion.status.humanize}")
    redirect_to epa_promotions_path, notice: "Keputusan panel disahkan dan dicatat."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, ArgumentError => error
    redirect_to epa_promotions_path, alert: error.message
  end

  def appeal
    promotion = EpaPromotion.find(params[:id])
    return deny_access unless promotion.student_id == current_user.id
    return module_disabled unless ModuleConfiguration.for(promotion.student.study_program).enabled?("epa")

    promotion.appeal!(reason: params[:reason])
    panel_recipients_for(promotion).each do |reviewer|
      Notification.notify!(recipient: reviewer, sender: current_user, notifiable: promotion,
        title: "Keberatan EPA menunggu panel", message: "#{promotion.epa.code}: mahasiswa mengajukan keberatan untuk ronde #{promotion.review_round}.")
    end
    redirect_to entrustment_decisions_path, notice: "Keberatan diterima dan dikirim untuk peninjauan panel baru."
  rescue ArgumentError, ActiveRecord::RecordInvalid => error
    redirect_to entrustment_decisions_path, alert: error.message
  end

  private

  def visible_promotions
    scope = EpaPromotion.where(status: %w[ready promoted under_review needs_more_evidence not_entrusted approved restricted deferred revoked appeal_pending])
    return scope.joins(student: :clinical_rotations)
      .where(clinical_rotations: { preceptor_id: current_user.id })
      .where("clinical_rotations.start_date <= ? AND clinical_rotations.end_date >= ?", Date.current, Date.current).distinct if current_user.has_role?("preseptor")

    assignments = UserAssignment.active.where(user: current_user, assignment_role: %w[epa_panel_member epa_panel_chair])
    promotion_ids = assignments.filter_map do |assignment|
      case assignment.scope_type
      when "User" then EpaPromotion.where(student_id: assignment.scope_id).pluck(:id)
      when "StudyProgram" then EpaPromotion.joins(:student).where(users: { study_program_id: assignment.scope_id }).pluck(:id)
      when "EpaPromotion" then assignment.scope_id
      when "ClinicalRotation"
        student_id = ClinicalRotation.where(id: assignment.scope_id).pick(:user_id)
        EpaPromotion.where(student_id: student_id).pluck(:id) if student_id
      else
        EpaPromotion.joins(:student).where(study_program_id: assignment.study_program_id).pluck(:id) if assignment.study_program_id
      end
    end.flatten.uniq
    scope.where(id: promotion_ids)
  end

  def preceptor_for?(student)
    current_user.id != student.id &&
      student.clinical_rotations.ongoing.exists?(preceptor: current_user)
  end

  def academic_authority_for?(promotion)
    current_user.id != promotion.student_id &&
      AssignmentAuthorization.assigned?(user: current_user, role: "epa_panel_member",
        student: promotion.student, object: promotion)
  end

  def committee_quorum_for(promotion)
    promotion.student.study_program.epa_panel_quorum
  end

  def chair_for?(promotion)
    AssignmentAuthorization.assigned?(user: current_user, role: "epa_panel_chair",
      student: promotion.student, object: promotion)
  end

  def panel_chairs_for(promotion)
    assigned_users_for(promotion, "epa_panel_chair")
  end

  def panel_recipients_for(promotion)
    ids = AssignmentAuthorization.panel_member_ids(student: promotion.student, promotion: promotion)
    User.where(id: (ids + panel_chairs_for(promotion).map(&:id)).uniq)
  end

  def assigned_users_for(promotion, role)
    UserAssignment.active.where(assignment_role: role).filter_map do |assignment|
      assignment.user if assignment.matches?(role: role, student: promotion.student, object: promotion)
    end.uniq
  end

  def deny_access
    redirect_to dashboard_path, alert: "Anda tidak memiliki kewenangan untuk tindakan EPA ini."
  end

  def module_disabled
    redirect_to epa_promotions_path, alert: "Input dan keputusan EPA untuk program studi ini sedang dinonaktifkan; riwayat tetap dapat dibaca."
  end
end
