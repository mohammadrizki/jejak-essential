require "test_helper"

class WpbaObservationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @instrument = WpbaInstrument.create!(code: "CUSTOM-HTTP-#{SecureRandom.hex(3)}", name: "Instrumen observasi", instrument_type: "other")
    @version = @instrument.versions.create!(version_label: "1.0", definition: {
      "components" => [{ "key" => "quality", "label" => "Mutu", "type" => "rating", "minimum" => 1, "maximum" => 5, "required" => true }]
    })
    @version.publish!(by: users(:budi))
  end

  test "penilai yang ditugaskan membuat dan mengirim observasi tambahan" do
    sign_in users(:budi)
    get new_wpba_observation_path
    assert_response :success
    assert_select "fieldset[data-version-id=?]", @version.id.to_s

    assert_difference "WpbaObservation.count", 1 do
      post wpba_observations_path, params: { wpba_observation: {
        student_id: users(:siti).id, clinical_rotation_id: clinical_rotations(:ongoing_rotation_siti).id,
        wpba_instrument_version_id: @version.id, observed_at: Time.current,
        activity_summary: "Melakukan konseling pasien", responses: { quality: "4" }
      } }
    end
    observation = WpbaObservation.order(:id).last
    assert_redirected_to wpba_observation_path(observation)
    patch submit_wpba_observation_path(observation)
    assert observation.reload.submitted?
    assert_equal users(:budi), observation.observer
  end

  test "metode WPBA bawaan memakai engine observasi yang sama dan EPA bukan instrumen WPBA" do
    WpbaInstrumentCatalog.ensure_defaults!
    cec = WpbaInstrumentCatalog.version_for("cec")
    sign_in users(:budi)

    get new_wpba_observation_path(wpba_instrument_version_id: cec.id)

    assert_response :success
    assert_select "option", text: /Clinical Encounter Card/
    assert_select "fieldset[data-version-id=?]", cec.id.to_s
    assert_no_match "EPA-OBS", response.body
  end

  test "form instrumen menampilkan jangkar perilaku pada setiap tingkat rating" do
    instrument = WpbaInstrument.create!(code: "ANCHORED-#{SecureRandom.hex(3)}", name: "Observasi berjangkar", instrument_type: "other")
    version = instrument.versions.create!(version_label: "1.0", definition: { components: [
      { key: "reasoning", label: "Penalaran", type: "rating", minimum: 1, maximum: 2, required: true,
        levels: { "1" => { label: "Dengan arahan", description: "Memerlukan prompt." },
                  "2" => { label: "Mandiri", description: "Menjelaskan keputusan." } }
      }
    ] })
    version.publish!(by: users(:budi))
    sign_in users(:budi)

    get new_wpba_observation_path(wpba_instrument_version_id: version.id)

    assert_response :success
    assert_select "select[name='wpba_observation[responses][reasoning]'] option", text: /1 · Dengan arahan — Memerlukan prompt\./
    assert_select "select[name='wpba_observation[responses][reasoning]'] option", text: /2 · Mandiri — Menjelaskan keputusan\./
  end

  test "dosen tanpa assignment tidak dapat membuat observasi" do
    unassigned = User.create!(full_name: "Dosen lain", email: "wpba-unassigned@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current)
    unassigned.roles << roles(:dosen)
    sign_in unassigned

    assert_no_difference "WpbaObservation.count" do
      post wpba_observations_path, params: { wpba_observation: {
        student_id: users(:siti).id, clinical_rotation_id: clinical_rotations(:ongoing_rotation_siti).id,
        wpba_instrument_version_id: @version.id, observed_at: Time.current,
        activity_summary: "Konseling pasien", responses: { quality: "4" }
      } }
    end
    assert_response :redirect
  end

  test "mahasiswa menautkan observasi WPBA terkirim ke syarat bukti" do
    observation = WpbaObservation.create!(student: users(:siti), observer: users(:budi),
      clinical_rotation: clinical_rotations(:ongoing_rotation_siti), wpba_instrument_version: @version,
      observed_at: Time.current, activity_summary: "Melakukan konseling pasien", status: "submitted",
      submitted_at: Time.current, responses: { "quality" => 4 })
    requirement = EvidenceRequirement.create!(origin: "manual", competency_item: competency_items(:sub_anamnesis),
      source_type: "wpba", required_count: 1)
    sign_in users(:siti)

    assert_difference "EvidenceRecord.count", 1 do
      post evidence_requirement_evidence_records_path(requirement), params: { evidence_record: {
        source_key: "wpba_observation-#{observation.id}", evidence_date: Date.current
      }, evidence_requirement_id: requirement.id }
    end
    assert EvidenceRecord.exists?(evidence_requirement: requirement, wpba_observation: observation)
  end

  test "riwayat dapat dibuka mahasiswa namun instrumen tidak aktif tidak dapat dipakai untuk input" do
    observation = WpbaObservation.create!(student: users(:siti), observer: users(:budi),
      clinical_rotation: clinical_rotations(:ongoing_rotation_siti), wpba_instrument_version: @version,
      observed_at: Time.current, activity_summary: "Observasi tindakan", status: "submitted",
      submitted_at: Time.current, responses: { "quality" => 3 })
    ModuleConfiguration.for(users(:siti).study_program).update!({ "wpba" => false }, actor: users(:dedi))
    sign_in users(:siti)
    get wpba_observation_path(observation)
    assert_response :success
    get new_wpba_observation_path
    assert_response :redirect
  end

  test "penilai lintas program mengikuti aktivasi WPBA program mahasiswa" do
    assessor = users(:budi)
    assessor.update!(study_program: study_programs(:profesi_dokter))
    admin = User.create!(full_name: "Admin modul", email: "admin-modul-wpba@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current)
    admin.roles << roles(:admin)
    ModuleConfiguration.for(assessor.study_program).update!({ wpba: false }, actor: admin)
    sign_in assessor

    assert_difference "WpbaObservation.count", 1 do
      post wpba_observations_path, params: { wpba_observation: {
        student_id: users(:siti).id, clinical_rotation_id: clinical_rotations(:ongoing_rotation_siti).id,
        wpba_instrument_version_id: @version.id, observed_at: Time.current,
        activity_summary: "Konseling pasien", responses: { quality: "4" }
      } }
    end
    assert_response :redirect
  end

  test "observasi baru ditolak bila WPBA program mahasiswa nonaktif meski penilai dari program aktif" do
    admin = User.create!(full_name: "Admin modul", email: "admin-modul-wpba-disabled@example.com",
      password: "rahasia-kuat-1", confirmed_at: Time.current)
    admin.roles << roles(:admin)
    ModuleConfiguration.for(users(:siti).study_program).update!({ wpba: false }, actor: admin)
    sign_in users(:budi)

    get new_wpba_observation_path
    assert_response :redirect

    assert_no_difference "WpbaObservation.count" do
      post wpba_observations_path, params: { wpba_observation: {
        student_id: users(:siti).id, clinical_rotation_id: clinical_rotations(:ongoing_rotation_siti).id,
        wpba_instrument_version_id: @version.id, observed_at: Time.current,
        activity_summary: "Konseling pasien", responses: { quality: "4" }
      } }
    end
    assert_response :redirect
  end
end
