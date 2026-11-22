require "test_helper"

class StudyProgramTest < ActiveSupport::TestCase
  test "jenjang mencakup spesialis dan subspesialis" do
    specialist = StudyProgram.create!(name: "Spesialis Anak", code: "sp-anak", level: "spesialis")
    subspecialist = StudyProgram.create!(name: "Subspesialis Kardiologi Anak", code: "subsp-anak-kardio", level: "subspesialis")

    assert specialist.spesialis?
    assert subspecialist.subspesialis?
    assert_equal "Subspesialis", subspecialist.level_label
  end

  test "prodi yang ada tetap dapat disunting di batas" do
    assert study_programs(:sarjana_kedokteran).update(name: "Sarjana Kedokteran Umum")
  end

  test "kode wajib unik dan huruf kecil" do
    program = StudyProgram.new(name: "Prodi Baru", code: "PSSK", level: "sarjana")
    program.valid?
    assert program.errors[:code].any?, "kode huruf besar harus ditolak"
  end

  test "EPA panel quorum is configurable and bounded" do
    program = study_programs(:profesi_dokter)
    assert_equal 1, program.epa_panel_quorum
    assert_not program.update(epa_panel_quorum: 0)
    assert_not program.update(epa_panel_quorum: 11)
    assert program.update(epa_panel_quorum: 3)
  end

  test "peta kompetensi terpilih harus dimiliki program studi" do
    program = study_programs(:sarjana_kedokteran)
    other_program_framework = CompetencyFramework.create!(
      study_program: study_programs(:profesi_dokter), name: "Peta Profesi untuk Uji"
    )

    assert_not program.update(competency_framework: other_program_framework)
    assert program.errors[:competency_framework].any?
    assert_equal study_programs(:sarjana_kedokteran).peta_kompetensi,
      program.reload.peta_kompetensi
  end
end
