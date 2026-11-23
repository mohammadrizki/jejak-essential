# Shared breadcrumbs follow the active role's navigation groups.
module NavigationHelper
  NAVIGATION_BREADCRUMBS = [
    [ %r{\A/competency_framework_templates}, "Pustaka Kerangka Kompetensi" ],
    [ %r{\A/(competency_frameworks|competency_items)}, "Peta Kompetensi" ],
    [ %r{\A/assessment_blueprints}, "Blueprint Asesmen" ],
    [ %r{\A/evidence_requirements}, "Bukti yang Diharapkan" ],
    [ %r{\A/peta-artefak}, "Peta Artefak" ],
    [ %r{\A/(clinical_cases|activity_logs|kalender)}, "Logbook Klinis" ],
    [ %r{\A/final_projects}, "Proyek Akhir" ],
    [ %r{\A/portfolio}, "Portofolio Saya" ],
    [ %r{\A/portofolio-terpilih}, "Portofolio Terpilih" ],
    [ %r{\A/reflection_entries}, "Refleksi Pengalaman Belajar" ],
    [ %r{\A/student/feedback_journal}, "Umpan Balik" ],
    [ %r{\A/(asesmen|dops_evaluations|mini_cex_evaluations|wpba_observations)}, "Workplace-Based Assessment" ],
    [ %r{\A/(nilai-ujian|student/assessments|examiner_evaluations)}, "Penilaian & Validasi Bukti" ],
    [ %r{\A/(artifact_submissions|evidence_sources)}, "Penilaian & Validasi Bukti" ],
    [ %r{\A/(assessment_form_templates|assessment_form_submissions|admin/assessment_events|admin/wpba_instruments)}, "Master Data" ],
    [ %r{\A/capaian-belajar}, "Capaian Kompetensi" ],
    [ %r{\A/(dashboard/entrustment|epa_observations|epa_promotions)}, "EPA" ],
    [ %r{\A/analitik}, "Dashboard Capaian" ],
    [ %r{\A/(study_programs|academic_periods|clinical_rotations|tutorial_enrollments)}, "Program Studi & Kurikulum" ],
    [ %r{\A/(admin/users|cari)}, "Pengguna & Hak Akses" ],
    [ %r{\A/(user_assignments|external_identity_mappings|external_evidence_imports)}, "Pengguna & Hak Akses" ],
    [ %r{\A/admin/}, "Master Data" ],
    [ %r{\A/module_configuration}, "Pengaturan Sistem" ],
    [ %r{\A/(monitoring-srq|kesehatan-mental)}, "Layanan Mahasiswa" ]
  ].freeze

  def navigation_breadcrumbs
    return [ [ "Dashboard", nil ] ] if request.path.in?(%w[/ /dashboard])

    mapping = NAVIGATION_BREADCRUMBS.find do |pattern, _item|
      pattern.match?(request.path) && !(request.path.start_with?("/clinical_cases", "/activity_logs") && params[:scope].in?(%w[to_verify reviewed]))
    end
    if request.path.start_with?("/clinical_cases", "/activity_logs") && params[:scope].in?(%w[to_verify reviewed])
      item = "Penilaian & Validasi Bukti"
    elsif mapping
      _pattern, item = mapping
    else
      return [ [ "Dashboard", dashboard_path ], [ content_for(:title).presence || "Halaman", nil ] ]
    end

    group = navigation_group_for(item)
    crumbs = [ [ "Dashboard", dashboard_path ], [ group, nil ], [ item, nil ] ]
    page_label = content_for(:page_title).presence || content_for(:title).presence
    crumbs << [ page_label, nil ] if page_label.present? && page_label != item && page_label != group
    crumbs
  end

  private

  def navigation_group_for(item)
    role = (current_user&.active_role || current_user&.roles&.first)&.code
    return "Target Kompetensi" if role == "mahasiswa" && item.in?([ "Peta Kompetensi", "Pustaka Kerangka Kompetensi", "Blueprint Asesmen", "Bukti yang Diharapkan", "Peta Artefak" ])
    return "Portofolio Saya" if role == "mahasiswa" && item.in?(%w[ Portofolio Saya Portofolio Terpilih Refleksi Pengalaman Belajar Umpan Balik ])
    return "Logbook Klinis" if role == "mahasiswa" && item == "Logbook Klinis"
    return "Workplace-Based Assessment" if role == "mahasiswa" && item == "Workplace-Based Assessment"
    return "EPA" if role == "mahasiswa" && item == "EPA"
    return "Capaian Saya" if role == "mahasiswa" && item == "Capaian Kompetensi"
    return "ADMINISTRASI" if role == "admin" || role == "tenaga_kependidikan"
    return "Pengelolaan Program Studi" if role == "kaprodi" && item.in?([ "Pustaka Kerangka Kompetensi", "Peta Kompetensi", "Blueprint Asesmen", "Bukti yang Diharapkan", "Peta Artefak" ])
    return "Monitoring Program Studi" if role == "kaprodi"
    return "Mahasiswa Supervisi" if role == "preseptor" && item == "Pengguna & Hak Akses"
    return "Workplace-Based Assessment" if %w[dosen preseptor].include?(role) && item.include?("Asesmen")
    return "Penilaian & Validasi Bukti" if %w[dosen preseptor].include?(role) && item == "Penilaian & Validasi Bukti"

    item
  end
end
