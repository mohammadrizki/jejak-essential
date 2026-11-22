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

  test "EPA dapat diaktifkan secara opsional pada jenjang Sarjana" do
    program = study_programs(:sarjana_kedokteran)
    configuration = ModuleConfiguration.for(program)

    configuration.update!({ "epa" => "1" }, actor: users(:dedi))

    assert configuration.enabled?("epa")
    assert ModuleConfigurationChange.exists?(study_program: program, actor: users(:dedi))
  end

  test "Kaprodi tidak dapat mengatur program studi lain" do
    configuration = ModuleConfiguration.for(study_programs(:profesi_dokter))

    assert_raises(Pundit::NotAuthorizedError) do
      configuration.update!({ "wpba" => "0" }, actor: users(:dedi))
    end
  end

  test "EPA bawaan tetap dapat digunakan secara terpisah dari modul WPBA umum" do
    program = study_programs(:profesi_dokter)
    admin = users(:budi)
    admin.roles << roles(:admin)
    configuration = ModuleConfiguration.for(program)

    configuration.update!({ "wpba" => "0" }, actor: admin)
    refute configuration.enabled?("wpba")
    assert configuration.enabled?("epa")
    refute configuration.enabled?("integration_clinical_wpba")

    configuration.update!({ "integration_clinical_wpba" => "1" }, actor: admin)
    assert configuration.enabled?("integration_clinical_wpba")
  end
end
