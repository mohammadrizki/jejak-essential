# frozen_string_literal: true

require "csv"

class PortfoliosController < ApplicationController
  before_action :authenticate_user!

  def show
    @logs = current_user.activity_logs
    @total = @logs.count
    @klinis_count = @logs.klinis.count
    @non_klinis_count = @logs.non_klinis.count
    @monthly_counts = @logs.group_by_month(:activity_date, last: 6).count
    # Kegiatan baru tidak lagi mengisi teks bebas activity_type — hitung dari
    # taksonomi (Bentuk Kegiatan → Subdomain), teks lama sebagai cadangan.
    @type_counts = @logs.with_taxonomy.filter_map(&:kind_label).tally.sort_by { |_, c| -c }.first(8)
    framework = current_user.study_program&.peta_kompetensi
    @evidence_requirements = if framework
      EvidenceRequirement.where(status: "active")
        .where(competency_item_id: framework.competency_items.select(:id))
        .or(EvidenceRequirement.where(status: "active", epa_id: framework.epas.select(:id)))
        .includes(:competency_item, :competency_indicator, :epa, :evidence_records)
    else
      EvidenceRequirement.none
    end
    @assessment_instances = current_user.assessment_instances.includes(:assessment_event).order(created_at: :desc)
    @epa_observations = if framework&.education_stage.in?(%w[professional specialist subspecialist])
      current_user.epa_observations.includes(:epa, :observer, :supervision_level).chronological
    else
      EpaObservation.none
    end
    @reflections = current_user.reflection_entries.recent
    @evidence_sources = {
      "assessment" => @assessment_instances.map { |record| ["Asesmen · #{record.assessment_event.name} · #{record.created_at.to_date}", "assessment_instance-#{record.id}"] },
      "logbook" => @logs.recent.map { |record| ["Logbook · #{record.title} · #{record.activity_date}", "activity_log-#{record.id}"] },
      "reflection" => @reflections.map { |record| ["Refleksi · #{record.entry_date}", "reflection_entry-#{record.id}"] },
      "portfolio" => @assessment_instances.map { |record| ["Asesmen · #{record.assessment_event.name}", "assessment_instance-#{record.id}"] } +
        @logs.recent.map { |record| ["Logbook · #{record.title}", "activity_log-#{record.id}"] } +
        @reflections.map { |record| ["Refleksi · #{record.entry_date}", "reflection_entry-#{record.id}"] },
      "other" => @assessment_instances.map { |record| ["Asesmen · #{record.assessment_event.name}", "assessment_instance-#{record.id}"] } +
        @logs.recent.map { |record| ["Logbook · #{record.title}", "activity_log-#{record.id}"] } +
        @reflections.map { |record| ["Refleksi · #{record.entry_date}", "reflection_entry-#{record.id}"] }
    }
  end

  def export
    logs = current_user.activity_logs.recent.with_taxonomy.includes(:academic_period, :clinical_rotation)

    csv = CSV.generate(headers: true) do |rows|
      rows << [ "Tanggal", "Waktu Mulai", "Waktu Selesai", "Domain", "Subdomain / Kategori", "Bentuk Kegiatan",
                "Klinis/Non-Klinis", "Topik", "Lokasi", "Metode", "Semester", "Rotasi", "Catatan", "Refleksi",
                "Jumlah Peserta", "Link Bukti", "Link Dokumen" ]
      logs.each do |log|
        rows << [ log.activity_date, log.started_at&.strftime("%H:%M"), log.ended_at&.strftime("%Y-%m-%d %H:%M"),
                  log.domain_label, log.academic_activity_subdomain&.name || log.activity_type,
                  log.academic_activity_template&.name, log.category_label, log.title, log.location,
                  log.delivery_mode_label, log.academic_period&.name, log.clinical_rotation&.station_name,
                  log.description, log.reflection, log.participant_count, log.evidence_url, log.document_url ]
      end
    end

    send_data csv, filename: "portfolio-#{current_user.full_name.parameterize}-#{Date.current}.csv"
  end
end
