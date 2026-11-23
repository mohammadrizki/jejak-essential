# frozen_string_literal: true

require "csv"

class PortfoliosController < ApplicationController
  before_action :authenticate_user!

  def show
    @student = current_user
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
    @epa_module_enabled = current_user.study_program.present? && ModuleConfiguration.for(current_user.study_program).enabled?("epa")
    # Disabling EPA stops new input, but a student's historical observations
    # remain visible in the portfolio collection.
    @epa_observations = current_user.epa_observations.includes(:epa, :observer, :supervision_level).chronological
    @reflections = current_user.reflection_entries.recent
    @wpba_observations = current_user.wpba_observations_as_student.submitted.includes(wpba_instrument_version: :wpba_instrument).recent
    @artifact_submissions = current_user.artifact_submissions.includes(:reviewer, :portfolio_selection).order(submitted_at: :desc)
    @portfolio_selections = current_user.portfolio_selections.includes(artifact_submission: :reviewer).order(selected_at: :desc)
    @collected_evidence = collected_evidence_entries
    @artifact_sources = current_user.activity_logs.verified.recent.map { |record| ["Logbook · #{record.title} · #{record.activity_date}", "ActivityLog", record.id] } +
      @reflections.map { |record| ["Refleksi · #{record.entry_date}", "ReflectionEntry", record.id] } +
      EvidenceRecord.includes(:evidence_requirement, :evidence_source)
        .joins(:evidence_source)
        .where(evidence_requirement_id: @evidence_requirements.select(:id))
        .where(evidence_sources: { student_id: current_user.id, validation_status: "validated" })
        .map { |record| ["Bukti tervalidasi · #{record.evidence_date} · #{record.evidence_requirement.source_type}", "EvidenceRecord", record.id] }
    @evidence_sources = {
      "assessment" => @assessment_instances.select { |record| record.status == "scored" && record.examiner.present? }
        .map { |record| ["Asesmen · #{record.assessment_event.name} · #{record.effective_date}", "assessment_instance-#{record.id}"] },
      "wpba" => current_user.mini_cex_evaluations_as_student.submitted.recent.map { |record| ["Mini-CEX · #{record.case_description} · #{record.evaluated_at}", "mini_cex_evaluation-#{record.id}"] } +
        current_user.dops_evaluations_as_student.submitted.recent.map { |record| ["DOPS · #{record.procedure_name} · #{record.evaluated_at}", "dops_evaluation-#{record.id}"] } +
        @wpba_observations.map { |record| ["#{record.wpba_instrument_version.wpba_instrument.name} · #{record.activity_summary} · #{record.observed_at.to_date}", "wpba_observation-#{record.id}"] } +
        @assessment_instances.select { |record| record.assessment_event.assessment_type == "cbd" && record.status == "scored" }
          .map { |record| ["CBD · #{record.assessment_event.name} · #{record.effective_date}", "assessment_instance-#{record.id}"] },
      "logbook" => @logs.verified.recent.map { |record| ["Logbook · #{record.title} · #{record.activity_date}", "activity_log-#{record.id}"] },
      "reflection" => @reflections.map { |record| ["Refleksi · #{record.entry_date}", "reflection_entry-#{record.id}"] },
      "epa_observation" => (@epa_module_enabled ? @epa_observations.usable_as_evidence : EpaObservation.none).map do |record|
        ["EPA · #{record.epa.code} · #{record.observed_at.to_date}", "epa_observation-#{record.id}"]
      end,
      "external" => current_user.evidence_sources.where(source_type: "external").order(occurred_on: :desc, id: :desc)
        .map { |record| ["Bukti eksternal · #{record.instrument_code.presence || record.source_record_id} · #{record.occurred_on} · #{validation_status_label(record.validation_status)}", "evidence_source-#{record.id}"] }
    }
    current_user.evidence_sources.where.not(source_system: "jejak").order(occurred_on: :desc, id: :desc).each do |source|
      next unless @evidence_sources.key?(source.source_type)

      label = "#{source.instrument_code.presence || source.source_type.humanize} · #{source.occurred_on} · #{validation_status_label(source.validation_status)}"
      @evidence_sources[source.source_type] << [label, "evidence_source-#{source.id}"]
    end
    broad_choices = %w[assessment wpba logbook reflection epa_observation external]
      .flat_map { |type| @evidence_sources.fetch(type, []) }.uniq { |_label, source_key| source_key }
    @evidence_sources["portfolio"] = broad_choices
    @evidence_sources["other"] = broad_choices
    @evidence_choices = @evidence_requirements.index_with do |requirement|
      source_type = requirement.current_version&.source_type || requirement.source_type
      existing_keys = requirement.evidence_records.select { |record| record.student&.id == current_user.id }.map(&:source_key)
      @evidence_sources.fetch(source_type, []).reject do |_label, source_key|
        choice_source_key(source_key).in?(existing_keys)
      end
    end
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

  private

  def choice_source_key(source_key)
    type, id = source_key.split("-", 2)
    case type
    when "assessment_instance" then ["assessment", id.to_i]
    when "activity_log" then ["logbook", id.to_i]
    when "reflection_entry" then ["reflection", id.to_i]
    when "epa_observation" then ["epa_observation", id.to_i]
    when "mini_cex_evaluation" then ["mini_cex", id.to_i]
    when "dops_evaluation" then ["dops", id.to_i]
    when "wpba_observation" then ["wpba", "wpba_observation:#{id}"]
    when "evidence_source"
      source = current_user.evidence_sources.find_by(id: id)
      ["canonical", source&.source_system, source&.activity_key]
    end
  end

  def collected_evidence_entries
    entries = @assessment_instances.map do |record|
      { date: record.effective_date, kind: "Asesmen", title: record.assessment_event.name,
        status: record.status_label, path: nil }
    end
    entries.concat(@logs.recent.limit(100).map do |record|
      { date: record.activity_date, kind: "Logbook", title: record.title,
        status: record.verified? ? "Tervalidasi" : "Menunggu validasi", path: activity_log_path(record) }
    end)
    entries.concat(@reflections.map do |record|
      { date: record.entry_date, kind: "Refleksi", title: record.title.presence || "Refleksi Pengalaman Belajar",
        status: "Tersimpan", path: reflection_entry_path(record) }
    end)
    entries.concat(current_user.mini_cex_evaluations_as_student.submitted.recent.map do |record|
      { date: record.evaluated_at.to_date, kind: "WPBA · Mini-CEX", title: record.case_description,
        status: "Terkirim", path: nil }
    end)
    entries.concat(current_user.dops_evaluations_as_student.submitted.recent.map do |record|
      { date: record.evaluated_at.to_date, kind: "WPBA · DOPS", title: record.procedure_name,
        status: "Terkirim", path: nil }
    end)
    entries.concat(@wpba_observations.map do |record|
      { date: record.observed_at.to_date, kind: "WPBA · #{record.wpba_instrument_version.wpba_instrument.name}",
        title: record.activity_summary, status: "Terkirim", path: nil }
    end)
    entries.concat(@epa_observations.map do |record|
      status = record.safety_flag? && record.safety_resolved_at.blank? ? "Tindak lanjut keselamatan" : record.status.humanize
      { date: record.observed_at.to_date, kind: "EPA", title: "#{record.epa.code} · #{record.epa.title}",
        status: status, path: nil }
    end)
    entries.concat(current_user.evidence_sources.where.not(source_system: "jejak").order(occurred_on: :desc, id: :desc).map do |record|
      { date: record.occurred_on, kind: "Bukti Terintegrasi", title: record.instrument_code.presence || record.source_record_id,
        status: validation_status_label(record.validation_status), path: nil }
    end)
    entries.sort_by { |entry| [entry[:date] || Date.new(1), entry[:kind], entry[:title]] }.reverse
  end

  def validation_status_label(status)
    { "unverified" => "Menunggu validasi", "validated" => "Tervalidasi", "rejected" => "Ditolak" }.fetch(status.to_s, status.to_s.humanize)
  end
end
