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
end
