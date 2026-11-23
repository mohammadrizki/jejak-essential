class AddAssessmentSchedulingModuleAndPerformedAt < ActiveRecord::Migration[8.1]
  def change
    add_column :assessment_instances, :performed_at, :datetime
    safety_assured do
      add_reference :evaluation_schedules, :assessment_event, foreign_key: { on_delete: :restrict }
    end

    # Sebelum pemisahan tanggal, importer lama menyimpan tanggal ujian sebagai
    # scored_at. Pertahankan tanggal historis tersebut sebagai tanggal aktual.
    reversible do |direction|
      direction.up do
        safety_assured do
          execute <<~SQL
            UPDATE assessment_instances
            SET performed_at = scored_at
            WHERE source = 'import' AND performed_at IS NULL AND scored_at IS NOT NULL
          SQL
        end
      end
    end
  end
end
