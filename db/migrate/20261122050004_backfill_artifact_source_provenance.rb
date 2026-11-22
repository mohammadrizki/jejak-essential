# frozen_string_literal: true

class BackfillArtifactSourceProvenance < ActiveRecord::Migration[8.1]
  def up
    # Keep only source pointers and labels. Do not copy clinical narrative.
    safety_assured do
      execute <<~SQL
        UPDATE artifact_submissions submission
        SET source_provenance = jsonb_build_object(
          'source_type', submission.source_type, 'source_id', submission.source_id,
          'source_version_at', source.updated_at, 'captured_at', CURRENT_TIMESTAMP,
          'provenance_quality', 'best_effort_legacy', 'occurred_on', source.activity_date,
          'label', source.title
        )
        FROM activity_logs source
        WHERE submission.source_type = 'ActivityLog' AND source.id = submission.source_id
          AND submission.source_provenance = '{}'::jsonb
      SQL
      execute <<~SQL
        UPDATE artifact_submissions submission
        SET source_provenance = jsonb_build_object(
          'source_type', submission.source_type, 'source_id', submission.source_id,
          'source_version_at', source.updated_at, 'captured_at', CURRENT_TIMESTAMP,
          'provenance_quality', 'best_effort_legacy', 'occurred_on', source.entry_date,
          'label', COALESCE(NULLIF(source.title, ''), 'Refleksi ' || source.entry_date::text)
        )
        FROM reflection_entries source
        WHERE submission.source_type = 'ReflectionEntry' AND source.id = submission.source_id
          AND submission.source_provenance = '{}'::jsonb
      SQL
      execute <<~SQL
        UPDATE artifact_submissions submission
        SET source_provenance = jsonb_build_object(
          'source_type', submission.source_type, 'source_id', submission.source_id,
          'source_version_at', source.updated_at, 'captured_at', CURRENT_TIMESTAMP,
          'provenance_quality', 'best_effort_legacy', 'occurred_on', source.evidence_date,
          'label', COALESCE(requirement.source_type, 'Bukti') || ' · ' || source.evidence_date::text
        )
        FROM evidence_records source
        LEFT JOIN evidence_requirements requirement ON requirement.id = source.evidence_requirement_id
        WHERE submission.source_type = 'EvidenceRecord' AND source.id = submission.source_id
          AND submission.source_provenance = '{}'::jsonb
      SQL
      execute <<~SQL
        UPDATE artifact_submissions
        SET source_provenance = jsonb_build_object(
          'source_type', source_type, 'source_id', source_id,
          'captured_at', CURRENT_TIMESTAMP, 'provenance_quality', 'source_unavailable_at_migration',
          'label', 'Artefak historis'
        )
        WHERE source_provenance = '{}'::jsonb
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Snapshot provenance artefak historis harus dipertahankan."
  end
end
