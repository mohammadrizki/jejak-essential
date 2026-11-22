# frozen_string_literal: true

class AddArtifactSourceProvenance < ActiveRecord::Migration[8.1]
  def change
    add_column :artifact_submissions, :source_provenance, :jsonb, null: false, default: {}
  end
end
