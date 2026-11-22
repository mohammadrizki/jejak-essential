# frozen_string_literal: true

class CreateArtifactSubmissionReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :artifact_submission_reviews do |t|
      t.references :artifact_submission, null: false, foreign_key: true
      t.references :reviewer, null: false, foreign_key: { to_table: :users }
      t.string :decision, null: false
      t.text :notes, null: false
      t.datetime :reviewed_at, null: false
      t.timestamps
    end
    add_index :artifact_submission_reviews, %i[artifact_submission_id reviewer_id reviewed_at],
      name: "idx_artifact_submission_review_history"
    add_check_constraint :artifact_submission_reviews, "decision IN ('approved', 'rejected')",
      name: "chk_artifact_submission_review_decision"
  end
end
