# frozen_string_literal: true

class ValidateAssignmentRevocationAudit < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :user_assignments, :users, column: :revoked_by_id
  end
end
