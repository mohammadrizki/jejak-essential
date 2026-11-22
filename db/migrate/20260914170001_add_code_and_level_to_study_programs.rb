class AddCodeAndLevelToStudyPrograms < ActiveRecord::Migration[8.1]
  def up
    add_column :study_programs, :code, :string
    add_column :study_programs, :level, :string

    # Dua baris tetap dari db/seeds.rb diberi kode (pssk/pspd).
    safety_assured do
      execute <<~SQL
      UPDATE study_programs SET code = 'pssk', level = 'sarjana' WHERE name = 'Sarjana Kedokteran';
      UPDATE study_programs SET code = 'pspd', level = 'profesi' WHERE name = 'Profesi Dokter';
      SQL
    end

    safety_assured { add_index :study_programs, :code, unique: true }
  end

  def down
    remove_index :study_programs, :code
    remove_column :study_programs, :level
    remove_column :study_programs, :code
  end
end
