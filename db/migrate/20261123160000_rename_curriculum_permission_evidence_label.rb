class RenameCurriculumPermissionEvidenceLabel < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      execute <<~SQL
        UPDATE system_permissions
        SET description = 'Mengelola peta kompetensi, blueprint, dan Bukti yang Diharapkan.'
        WHERE key = 'curriculum.manage'
      SQL
    end
  end

  def down
    safety_assured do
      execute <<~SQL
        UPDATE system_permissions
        SET description = 'Mengelola peta kompetensi, blueprint, dan syarat bukti.'
        WHERE key = 'curriculum.manage'
      SQL
    end
  end
end
