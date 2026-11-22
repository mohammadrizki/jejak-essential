# frozen_string_literal: true

class AddReviewDueNotificationToEntrustmentDecisions < ActiveRecord::Migration[8.1]
  def change
    add_column :entrustment_decisions, :review_due_notified_at, :datetime
  end
end
