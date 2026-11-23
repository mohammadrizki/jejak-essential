require "test_helper"

class EvidenceRequirementsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "kaprodi hanya melihat bukti yang diharapkan milik program studinya" do
    own_requirement = EvidenceRequirement.create!(origin: "manual", competency_item: competency_items(:sub_anamnesis),
      source_type: "wpba", required_count: 1)
    other_framework = CompetencyFramework.create!(name: "Peta Profesi Terpisah", study_program: study_programs(:profesi_dokter),
      education_stage: "profesi")
    other_domain = other_framework.competency_items.create!(title: "Kompetensi Program Lain")
    other_requirement = EvidenceRequirement.create!(origin: "manual", competency_item: other_domain,
      source_type: "wpba", required_count: 1)
    sign_in users(:dedi)

    get evidence_requirements_path

    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "tbody td", text: /#{Regexp.escape(own_requirement.competency_item.title)}/
    assert_select "tbody td", { text: /#{Regexp.escape(other_requirement.competency_item.title)}/, count: 0 }
  end

  test "administrator tetap dapat meninjau bukti yang diharapkan lintas program" do
    requirement = EvidenceRequirement.create!(origin: "manual", competency_item: competency_items(:sub_anamnesis),
      source_type: "wpba", required_count: 1)
    admin = users(:budi)
    grant_bootstrapped_system_admin!(admin)
    admin.update!(active_role: roles(:admin))
    sign_in admin

    get evidence_requirements_path

    assert_response :success
    assert_select "tbody td", text: /#{Regexp.escape(requirement.competency_item.title)}/
  end
end
