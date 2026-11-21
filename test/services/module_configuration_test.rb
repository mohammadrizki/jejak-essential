require "test_helper"

class ModuleConfigurationTest < ActiveSupport::TestCase
  test "Core selalu aktif dan default modul menjaga fitur lama pada Sarjana" do
    configuration = ModuleConfiguration.for(study_programs(:sarjana_kedokteran))

    assert configuration.enabled?("core_eportfolio")
    assert configuration.enabled?("clinical_logbook")
    assert configuration.enabled?("wpba")
    refute configuration.enabled?("epa")
  end

  test "Kaprodi dapat mengubah modul prodi sendiri dan perubahan memiliki audit append-only" do
    program = study_programs(:sarjana_kedokteran)
    actor = users(:dedi)
    configuration = ModuleConfiguration.for(program)

    configuration.update!({ "clinical_logbook" => "0" }, actor: actor)

    refute configuration.enabled?("clinical_logbook")
    assert configuration.enabled?("core_eportfolio")
    change = ModuleConfigurationChange.find_by!(study_program: program, actor: actor)
    assert_equal true, change.before_value.fetch("clinical_logbook")
    assert_equal false, change.after_value.fetch("clinical_logbook")
    refute change.destroy
  end

  test "EPA tidak dapat diaktifkan di Sarjana" do
    configuration = ModuleConfiguration.for(study_programs(:sarjana_kedokteran))

    error = assert_raises(ArgumentError) do
      configuration.update!({ "epa" => "1" }, actor: users(:dedi))
    end

    assert_match "jenjang Sarjana", error.message
    assert_empty ModuleConfigurationChange.where(study_program: study_programs(:sarjana_kedokteran))
  end

  test "Kaprodi tidak dapat mengatur program studi lain" do
    configuration = ModuleConfiguration.for(study_programs(:profesi_dokter))

    assert_raises(Pundit::NotAuthorizedError) do
      configuration.update!({ "wpba" => "0" }, actor: users(:dedi))
    end
  end
end
