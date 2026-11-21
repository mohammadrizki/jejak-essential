require "test_helper"

class AssessmentBlueprintsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "mahasiswa tidak boleh mengakses" do
    sign_in users(:siti)
    get assessment_blueprints_path
    assert_response :redirect
  end

  test "admin bisa melihat daftar blueprint" do
    admin = users(:budi)
    admin.roles << roles(:admin)
    sign_in admin

    get assessment_blueprints_path
    assert_response :success
    assert_match assessment_blueprints(:osce_blueprint).name, response.body
  end

  test "admin membuat blueprint dan memetakan kompetensi pada komponen versi draf" do
    admin = users(:budi)
    admin.roles << roles(:admin)
    sign_in admin
    program = create_test_program

    assert_difference "AssessmentBlueprint.count", 1 do
      post assessment_blueprints_path, params: {
        assessment_blueprint: {
          name: "Blueprint Baru",
          study_program_id: program.id,
          description: "Contoh",
          learning_outcomes_text: "Mampu mendiagnosis nyeri dada"
        }
      }
    end

    blueprint = AssessmentBlueprint.find_by(name: "Blueprint Baru")
    assert_equal [ "Mampu mendiagnosis nyeri dada" ], blueprint.learning_outcomes

    assert_difference "BlueprintItemCompetency.count", 1 do
      post assessment_blueprint_blueprint_items_path(blueprint), params: {
        blueprint_item: {
          code: "C-01", title: "CBT Kardiovaskular",
          assessment_method_id: create_assessment_method.id,
          competency_item_ids: [ blueprint.study_program.peta_kompetensi.domains.first.id ]
        }
      }
    end
    assert_equal 1, blueprint.reload.draft_version.blueprint_items.count
  end

  test "kaprodi dibatasi pada blueprint program studinya" do
    kaprodi = users(:dedi)
    program = StudyProgram.create!(name: "Program Kaprodi Uji", code: "kaprodi-#{SecureRandom.hex(3)}", level: "sarjana")
    kaprodi.update!(study_program: program)
    sign_in kaprodi

    assert_difference "AssessmentBlueprint.count", 1 do
      post assessment_blueprints_path, params: {
          assessment_blueprint: { name: "Blueprint Kaprodi", study_program_id: program.id }
      }
    end

    assert_no_difference "AssessmentBlueprint.count" do
      post assessment_blueprints_path, params: {
        assessment_blueprint: { name: "Blueprint Program Lain", study_program_id: study_programs(:profesi_dokter).id }
      }
    end
    assert_response :redirect
  end

  test "mahasiswa tidak bisa menambah mapping" do
    sign_in users(:siti)

    assert_no_difference "AssessmentBlueprintMapping.count" do
      post assessment_blueprint_assessment_blueprint_mappings_path(assessment_blueprints(:osce_blueprint)), params: {
        assessment_blueprint_mapping: { competency_item_id: competency_items(:domain_komunikasi).id, weight: 10 }
      }
    end
  end

  test "formulir tambah mapping di halaman detail mengirim parameter yang diterima controller" do
    admin = users(:budi)
    admin.roles << roles(:admin)
    sign_in admin
    blueprint = AssessmentBlueprint.create!(name: "Blueprint Kosong", study_program: create_test_program)

    get assessment_blueprint_path(blueprint)
    assert_select "form[action=?]", assessment_blueprint_blueprint_items_path(blueprint) do
      assert_select "select[name=?]", "blueprint_item[competency_item_ids][]"
      assert_select "input[name=?]", "blueprint_item[title]"
    end
  end

  test "blueprint yang dipakai unit pembelajaran bisa dihapus; unitnya tetap ada" do
    admin = users(:budi)
    admin.roles << roles(:admin)
    sign_in admin
    blueprint = AssessmentBlueprint.create!(name: "Blueprint Lepas", study_program: create_test_program)
    unit = LearningUnit.create!(name: "Blok Uji", study_program: study_programs(:sarjana_kedokteran), assessment_blueprint: blueprint)

    assert_no_difference "AssessmentBlueprint.count" do
      delete assessment_blueprint_path(blueprint)
    end
    assert_equal blueprint.id, unit.reload.assessment_blueprint_id
    assert AssessmentBlueprint.exists?(blueprint.id)
  end

  private

  def create_test_program
    program = StudyProgram.create!(name: "Program Blueprint Uji", code: "bp-#{SecureRandom.hex(3)}", level: "sarjana")
    framework = CompetencyFramework.create!(study_program: program, name: "Peta Blueprint Uji", version: "1",
      education_stage: "undergraduate")
    framework.competency_items.create!(title: "Domain Uji", code: "D-01", level_type: "domain")
    framework.publish!
    program.reload
  end

  def create_assessment_method
    AssessmentMethod.create!(code: "cbt-test", name: "Uji CBT", assessment_type: "written")
  end
end
