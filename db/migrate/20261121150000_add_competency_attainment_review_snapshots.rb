# frozen_string_literal: true

class AddCompetencyAttainmentReviewSnapshots < ActiveRecord::Migration[8.1]
  def change
    add_column :competency_attainments, :framework_version, :string
    add_column :competency_attainments, :evidence_snapshot, :jsonb, null: false, default: {}
    add_column :competency_attainments, :reviewed_at, :datetime
    add_column :competency_attainments, :review_notes, :text
    safety_assured do
      add_reference :competency_attainments, :reviewed_by, foreign_key: { to_table: :users }
    end

    create_table :competency_attainment_reviews do |t|
      t.references :competency_attainment, null: false, foreign_key: true
      t.references :reviewer, null: false, foreign_key: { to_table: :users }
      t.string :decision, null: false
      t.text :notes, null: false
      t.datetime :reviewed_at, null: false
      t.datetime :created_at, null: false
    end
    add_check_constraint :competency_attainment_reviews, "decision IN ('approved', 'rejected')",
      name: "chk_competency_attainment_review_decision"
  end
end
