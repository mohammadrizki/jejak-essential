# frozen_string_literal: true

class ValidateWpbaCorrectionForeignKeys < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :mini_cex_evaluations, column: :corrects_id
    validate_foreign_key :dops_evaluations, column: :corrects_id
  end
end
