# frozen_string_literal: true

class AddWpbaCorrectionLineage < ActiveRecord::Migration[8.1]
  def change
    add_column :mini_cex_evaluations, :correction_reason, :text
    add_column :dops_evaluations, :correction_reason, :text
    safety_assured do
      add_reference :mini_cex_evaluations, :corrects, index: { unique: true },
        foreign_key: { to_table: :mini_cex_evaluations, on_delete: :restrict, validate: false,
          name: "fk_minicex_correction_parent" }
      add_reference :dops_evaluations, :corrects, index: { unique: true },
        foreign_key: { to_table: :dops_evaluations, on_delete: :restrict, validate: false,
          name: "fk_dops_correction_parent" }
    end
  end
end
