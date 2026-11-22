# frozen_string_literal: true

class EpaEntrustmentReviewDueJob < ApplicationJob
  queue_as :default

  def perform(now = Time.current)
    EntrustmentDecision.where(decision_status: %w[active restricted])
      .where.not(valid_until: nil).where(valid_until: ..now).find_each { |decision| decision.expire!(at: now) }

    EntrustmentDecision.current.where.not(review_due_at: nil)
      .where(review_due_at: ..now, review_due_notified_at: nil)
      .includes(:student, :epa, :decided_by, :epa_promotion)
      .find_each do |decision|
        notify_once!(decision, now)
      end
  end

  private

  def notify_once!(decision, now)
    decision.with_lock do
      return if decision.superseded_at.present? || decision.review_due_at.nil? ||
        decision.review_due_at > now || decision.review_due_notified_at.present?

      recipients_for(decision).each do |recipient|
        Notification.notify!(recipient: recipient, notifiable: decision,
          title: "Tinjauan EPA telah jatuh tempo",
          message: "Keputusan #{decision.epa.code} untuk #{decision.student.full_name} perlu ditinjau ulang.",
          notification_type: "epa_entrustment_review_due")
      end
      decision.with_lifecycle_transition { decision.update!(review_due_notified_at: now) }
    end
  end

  def recipients_for(decision)
    recipients = [decision.student, decision.decided_by]
    decision.student.clinical_rotations.ongoing.includes(:preceptor).each do |rotation|
      recipients << rotation.preceptor
    end

    if decision.epa_promotion
      promotion = decision.epa_promotion
      panel_member_ids = AssignmentAuthorization.panel_member_ids(student: decision.student, promotion: promotion)
      recipients.concat(User.where(id: panel_member_ids))
      recipients.concat(assigned_users_for("epa_panel_chair", decision.student, promotion))
    end

    recipients.compact.uniq
  end

  def assigned_users_for(role, student, promotion)
    UserAssignment.active.where(assignment_role: role).filter_map do |assignment|
      assignment.user if assignment.matches?(role: role, student: student, object: promotion)
    end
  end
end
