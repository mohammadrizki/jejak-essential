require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "mahasiswa melihat tahap OBE yang sesuai dan tidak melihat menu EPA Sarjana" do
    sign_in users(:siti)

    get dashboard_path

    assert_response :success
    assert_select "nav[aria-label='Breadcrumb']"
    assert_select "button", text: /1\. PERUMUSAN CAPAIAN/
    assert_select "button", text: /2\. PENGEMBANGAN KOMPETENSI/
    assert_select "button", text: /3\. ASESMEN CAPAIAN/
    assert_select "button", text: /4\. EVALUASI & PENINGKATAN MUTU/
    assert_select "a[href='#{competency_framework_templates_path}']", text: "Pustaka Kerangka Kompetensi"
    assert_select "a[href='#{entrustment_decisions_path}']", count: 0
    assert_select "a[href='#{assessment_blueprints_path}']", count: 0
    assert_select "a", text: "Peta Artefak", count: 0
  end

  test "admin melihat tautan konfigurasi turunan dan breadcrumb tahap" do
    admin = users(:budi)
    admin.roles << roles(:admin)
    sign_in admin

    get competency_framework_templates_path

    assert_response :success
    assert_select "nav[aria-label='Breadcrumb']", text: /Perumusan Capaian/
    get dashboard_path
    assert_response :success
    assert_select "a[href='#{assessment_blueprints_path}']", text: "Blueprint Asesmen"
    assert_select "a[href='#{evidence_requirements_path}']", text: "Syarat Bukti"
    assert_select "a[href='#{artifact_map_path}']", text: "Peta Artefak"
  end

  test "halaman turunan peta artefak dan syarat bukti dibatasi pada admin" do
    sign_in users(:siti)

    get artifact_map_path
    assert_response :redirect
    get evidence_requirements_path
    assert_response :redirect
  end

  test "admin dapat membuka peta artefak dan daftar syarat bukti tanpa tabel master artefak" do
    admin = users(:budi)
    admin.roles << roles(:admin)
    sign_in admin

    get artifact_map_path
    assert_response :success
    assert_match "tampilan turunan", response.body

    get evidence_requirements_path
    assert_response :success
    assert_match "Syarat Bukti", response.body
  end
end
