# Shared breadcrumb taxonomy for the four OBE stages and administration.
module NavigationHelper
  OBE_BREADCRUMBS = [
    [ %r{\A/competency_framework_templates}, "Perumusan Capaian", "Pustaka Kerangka Kompetensi" ],
    [ %r{\A/(competency_frameworks|competency_items)}, "Perumusan Capaian", "Peta Kompetensi" ],
    [ %r{\A/assessment_blueprints}, "Perumusan Capaian", "Blueprint Asesmen" ],
    [ %r{\A/evidence_requirements}, "Perumusan Capaian", "Syarat Bukti" ],
    [ %r{\A/peta-artefak}, "Perumusan Capaian", "Peta Artefak" ],
    [ %r{\A/(clinical_cases|activity_logs|kalender)}, "Pengembangan Kompetensi", "Logbook Klinis" ],
    [ %r{\A/admin/learning_units}, "Pengembangan Kompetensi", "Rencana Pembelajaran" ],
    [ %r{\A/(clinical_rotations|tutorial_enrollments)}, "Administrasi", "Program Studi & Kurikulum" ],
    [ %r{\A/final_projects}, "Portofolio", "Proyek Akhir" ],
    [ %r{\A/portfolio}, "Pengembangan Kompetensi", "Portofolio Saya" ],
    [ %r{\A/portofolio-terpilih}, "Pengembangan Kompetensi", "Portofolio Terpilih" ],
    [ %r{\A/reflection_entries}, "Pengembangan Kompetensi", "Refleksi Pengalaman Belajar" ],
    [ %r{\A/student/feedback_journal}, "Pengembangan Kompetensi", "Umpan Balik" ],
    [ %r{\A/(asesmen|dops_evaluations|mini_cex_evaluations)}, "Pengembangan Kompetensi", "Workplace-Based Assessment (WPBA)" ],
    [ %r{\A/(nilai-ujian|student/assessments|examiner_evaluations)}, "Asesmen Capaian", "Penilaian & Validasi Bukti" ],
    [ %r{\A/artifact_submissions}, "Asesmen Capaian", "Penilaian & Validasi Bukti" ],
    [ %r{\A/evidence_sources}, "Asesmen Capaian", "Penilaian & Validasi Bukti" ],
    [ %r{\A/(assessment_form_templates|assessment_form_submissions)}, "Administrasi", "Master Data" ],
    [ %r{\A/capaian-belajar}, "Asesmen Capaian", "Capaian Kompetensi" ],
    [ %r{\A/(dashboard/entrustment|epa_observations|epa_promotions)}, "Asesmen Capaian", "Keputusan EPA" ],
    [ %r{\A/analitik}, "Evaluasi & Peningkatan Mutu", "Dashboard Capaian" ],
    [ %r{\A/monitoring-srq}, "Layanan Mahasiswa", "Tindak Lanjut SRQ" ],
    [ %r{\A/kesehatan-mental}, "Layanan Mahasiswa", "Skrining Kesehatan (SRQ-20)" ],
    [ %r{\A/study_programs}, "Administrasi", "Program Studi & Kurikulum" ],
    [ %r{\A/academic_periods}, "Administrasi", "Program Studi & Kurikulum" ],
    [ %r{\A/admin/(evaluation_schedules|student_relabel|learning_units)}, "Administrasi", "Program Studi & Kurikulum" ],
    [ %r{\A/(admin/users|cari)}, "Administrasi", "Pengguna & Hak Akses" ],
    [ %r{\A/admin/(assessment_events|wpba_instruments|cbt_exams|glide_syncs|logbook_case_targets|academic_activity_domains|academic_activity_subdomains|academic_activity_templates|diagnosis_definitions|skill_definitions|medication_definitions|exports)}, "Administrasi", "Master Data" ],
    [ %r{\A/admin/(terminology|data_governance)}, "Administrasi", "Pengaturan Sistem" ],
    [ %r{\A/module_configuration}, "Administrasi", "Pengaturan Sistem" ],
    [ %r{\A/(user_assignments|external_identity_mappings|external_evidence_imports)}, "Administrasi", "Pengguna & Hak Akses" ]
  ].freeze

  def navigation_breadcrumbs
    return [ [ "Dashboard", nil ] ] if request.path.in?(%w[/ /dashboard])

    mapping = OBE_BREADCRUMBS.find do |pattern, _group, _item|
      pattern.match?(request.path) && !(request.path.start_with?("/clinical_cases", "/activity_logs") && params[:scope].in?(%w[to_verify reviewed]))
    end
    if request.path.start_with?("/clinical_cases", "/activity_logs") && params[:scope].in?(%w[to_verify reviewed])
      group, item = "Asesmen Capaian", "Penilaian & Validasi Bukti"
    elsif mapping
      _pattern, group, item = mapping
    else
      return [ [ "Dashboard", dashboard_path ], [ content_for(:title).presence || "Halaman", nil ] ]
    end

    crumbs = [ [ "Dashboard", dashboard_path ], [ group, nil ], [ item, nil ] ]
    page_label = content_for(:page_title).presence || content_for(:title).presence
    crumbs << [ page_label, nil ] if page_label.present? && page_label != item && page_label != group
    crumbs
  end
end
