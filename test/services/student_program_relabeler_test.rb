require "test_helper"

class StudentProgramRelabelerTest < ActiveSupport::TestCase
  test "service legacy tidak dapat memindahkan mahasiswa secara langsung" do
    student = users(:siti)
    source = student.study_program
    legacy = StudentProgramRelabeler.new(csv: "email\nsiti@example.com\n", mode: "pindah",
      target_study_program: study_programs(:profesi_dokter))

    error = assert_raises(StudentProgramRelabeler::Error) { legacy.apply! }

    assert_match "alur Transfer Mahasiswa", error.message
    assert_equal source, student.reload.study_program
  end
end
