require "test_helper"

# Cangkang UI (Fase 22): sidebar berkelompok mengikuti peran aktif, topbar,
# bilah bawah mobile, dan preferensi tampilan.
class AppShellTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "mahasiswa melihat navigasi target dan portofolio tanpa administrasi" do
    sign_in users(:siti)
    get dashboard_path

    assert_response :success
    assert_select "aside#sidebar" do
      assert_select "p", text: "DASHBOARD"
      assert_select "span", text: "Target Kompetensi"
      assert_select "span", text: "Portofolio Saya"
      assert_select "span", text: "Capaian Saya"
      assert_no_match "PERUMUSAN CAPAIAN", response.body
      assert_select "a[href=?]", portfolio_path, text: "Koleksi Bukti"
      assert_select "a[href=?]", artifact_map_path, text: "Peta Artefak Saya"
      assert_select "p", text: "ADMINISTRASI", count: 0
    end
    # Pencarian pengguna khusus pengajar/kaprodi/admin — ikonnya tidak tampil.
    assert_select "header a[href=?]", search_path, count: 0
    assert_select ".mobile-bottom-nav a[href=?]", student_assessments_path
  end

  test "dosen melihat mahasiswa bimbingan, validasi, dan monitoring tanpa administrasi" do
    sign_in users(:budi)
    get dashboard_path
    assert_select "header a[href=?]", search_path

    pending = ClinicalCase.awaiting_verification.count
    assert_select "aside#sidebar" do
      assert_select "span", text: "Mahasiswa Bimbingan"
      assert_select "a[href=?]", clinical_cases_path(scope: "to_verify"), text: /Validasi Kasus/
      assert_select "a[href=?]", analytics_path
      assert_select "a[href=?]", study_programs_path, count: 0
      assert_select "a[href=?]", admin_wpba_instruments_path, count: 0
      assert_select "a[href=?]", portfolio_path, count: 0
    end
    assert_select ".mobile-bottom-nav a[href=?]", clinical_cases_path(scope: "to_verify")
    assert_match(/#{pending}/, response.body) if pending.positive?
  end

  test "admin melihat kelompok administrasi dan konfigurasi yang tersedia" do
    admin_user = users(:budi)
    grant_bootstrapped_system_admin!(admin_user)
    admin_user.update!(active_role: roles(:admin))
    sign_in admin_user

    get dashboard_path

    assert_select "aside#sidebar" do
    assert_select "p", text: "ADMINISTRASI"
      assert_select "span", text: "Program Studi & Kurikulum"
      assert_select "a[href=?]", academic_periods_path
      assert_select "a[href=?]", admin_assessment_events_path
      assert_select "a[href=?]", admin_wpba_instruments_path
    end
    # Pengalih peran tampil di topbar karena akun ini punya >1 peran.
    assert_select "header select#role_code option", minimum: 2
  end

  test "sidebar menandai menu halaman yang sedang dibuka" do
    sign_in users(:siti)
    get clinical_cases_path

    assert_select "aside#sidebar a.bg-indigo-600[href=?]", clinical_cases_path
    assert_select "aside#sidebar [data-controller=accordion][data-accordion-open-value=true] [data-accordion-target=content]:not(.hidden)", minimum: 1
  end

  test "halaman tamu tidak memuat sidebar" do
    get new_user_session_path

    assert_response :success
    assert_select "aside#sidebar", count: 0
  end

  test "preferensi tampilan tersimpan dan terpasang di html" do
    sign_in users(:siti)

    get my_settings_path
    assert_response :success

    patch update_appearance_settings_path, params: { user: { theme_preference: "dark", font_size_preference: "large" } }
    assert_redirected_to my_settings_path
    assert_equal "dark", users(:siti).reload.theme_preference

    get dashboard_path
    assert_select "html[data-theme-preference=dark][data-font-size-preference=large]"
  end

  test "tombol tema topbar menyimpan lewat JSON" do
    sign_in users(:siti)

    patch update_appearance_settings_path, params: { user: { theme_preference: "light" } }, as: :json
    assert_response :no_content
    assert_equal "light", users(:siti).reload.theme_preference
  end

  test "nilai preferensi di luar pilihan ditolak" do
    sign_in users(:siti)

    patch update_appearance_settings_path, params: { user: { theme_preference: "neon" } }
    assert_response :unprocessable_entity
    assert_equal "system", users(:siti).reload.theme_preference
  end
test "tombol EN di topbar mengganti bahasa cangkang dan tersimpan di akun" do
  sign_in users(:siti)

  patch update_locale_settings_path, params: { locale: "en" }, headers: { "HTTP_REFERER" => dashboard_path }
  assert_redirected_to dashboard_path
  assert_equal "en", users(:siti).reload.locale_preference

  get dashboard_path
  assert_select "html[lang=en]"
  assert_select "aside#sidebar a[href=?]", portfolio_path, text: "Koleksi Bukti"
  assert_select "header button", text: "ID"

  patch update_locale_settings_path, params: { locale: "id" }, headers: { "HTTP_REFERER" => dashboard_path }
  get dashboard_path
  assert_select "aside#sidebar a[href=?]", portfolio_path, text: "Koleksi Bukti"
end

test "bahasa yang tidak didukung ditolak" do
  sign_in users(:siti)
  patch update_locale_settings_path, params: { locale: "fr" }, headers: { "HTTP_REFERER" => dashboard_path }
  assert_equal "id", users(:siti).reload.locale_preference
end

test "halaman masuk mengikuti bahasa session setelah keluar" do
  sign_in users(:siti)
  patch update_locale_settings_path, params: { locale: "en" }, headers: { "HTTP_REFERER" => dashboard_path }
  delete destroy_user_session_path

  get new_user_session_path
  assert_select "html[lang=en]"
end
end
