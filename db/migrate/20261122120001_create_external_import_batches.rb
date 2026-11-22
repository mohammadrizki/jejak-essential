# frozen_string_literal: true

class CreateExternalImportBatches < ActiveRecord::Migration[8.1]
  def change
    create_table :external_import_batches do |t|
      t.references :study_program, null: false, foreign_key: true
      t.references :uploaded_by, null: false, foreign_key: { to_table: :users }
      t.string :source_system, null: false
      t.string :filename, null: false
      t.string :file_sha256, null: false
      t.string :status, null: false, default: "previewed"
      t.integer :row_count, null: false, default: 0
      t.integer :imported_count, null: false, default: 0
      t.jsonb :row_results, null: false, default: []
      t.datetime :completed_at
      t.timestamps
    end

    add_index :external_import_batches, %i[study_program_id created_at],
      name: "idx_external_import_batches_program_created"
  end
end
