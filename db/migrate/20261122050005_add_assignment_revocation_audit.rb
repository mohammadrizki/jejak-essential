# frozen_string_literal: true

class AddAssignmentRevocationAudit < ActiveRecord::Migration[8.1]
  def change
    add_reference :user_assignments, :revoked_by, index: false
    safety_assured do
      add_foreign_key :user_assignments, :users, column: :revoked_by_id, validate: false
    end
  end
end
