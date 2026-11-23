# frozen_string_literal: true

class EvidenceRecordsController < ApplicationController
  before_action :authenticate_user!

  def create
    requirement = EvidenceRequirement.find(params[:evidence_requirement_id])
    unless requirement_for_current_student?(requirement)
      return redirect_to portfolio_path, alert: "Bukti yang Diharapkan ini bukan milik program studi Anda."
    end
    source = owned_source
    source_record = owned_source_record
    return redirect_to portfolio_path(anchor: "requirement-#{requirement.id}"), alert: "Pilih bukti yang Anda miliki." if source.blank? || source_record.blank?
    required_type = requirement.current_version&.source_type || requirement.source_type
    source_module = case required_type
    when "epa_observation" then "epa"
    when "wpba" then "wpba"
    when "logbook" then "clinical_logbook"
    end
    source_module ||= "epa" if source == :epa_observation ||
      (source == :evidence_source && source_record.source_type == "epa_observation")
    if source_module && !ModuleConfiguration.for(current_user.study_program).enabled?(source_module)
      return redirect_to portfolio_path(anchor: "requirement-#{requirement.id}"),
        alert: "Modul #{source_module.humanize} tidak aktif. Bukti historis tetap dapat dibaca, tetapi tidak dapat ditautkan sebagai bukti baru."
    end
    if source == :evidence_source && source_record.source_system.present?
      integration_module = {
        "moodle" => "integration_moodle", "examtool" => "integration_examtool",
        "osce" => "integration_osce", "clinical_wpba" => "integration_clinical_wpba"
      }[source_record.source_system]
      if integration_module && !ModuleConfiguration.for(current_user.study_program).enabled?(integration_module)
        return redirect_to portfolio_path(anchor: "requirement-#{requirement.id}"),
          alert: "Adapter sumber bukti tidak aktif. Bukti historis tetap dapat dibaca, tetapi tidak dapat ditautkan sebagai bukti baru."
      end
    end
    unless source_matches_requirement?(source, source_record, required_type)
      return redirect_to portfolio_path(anchor: "requirement-#{requirement.id}"), alert: "Jenis bukti tidak sesuai dengan aturan ini."
    end

    record = requirement.evidence_records.new(
      source => source_record,
      evidence_date: params.dig(:evidence_record, :evidence_date).presence || Date.current,
      result: initial_result(source_record),
      score: source_record.respond_to?(:score) ? source_record.score : nil,
      metadata: { submitted_by_student_id: current_user.id }
    )
    if record.save
      redirect_to portfolio_path(anchor: "requirement-#{requirement.id}"), notice: "Bukti aktual ditautkan ke target."
    else
      redirect_to portfolio_path(anchor: "requirement-#{requirement.id}"), alert: record.errors.full_messages.to_sentence
    end
  end

  private

  def owned_source
    params.dig(:evidence_record, :source_key).to_s.split("-").first.presence&.to_sym
  end

  def owned_source_record
    type, id = params.dig(:evidence_record, :source_key).to_s.split("-", 2)
    case owned_source
    when :assessment_instance then current_user.assessment_instances.find_by(id: id) if type == "assessment_instance"
    when :activity_log then current_user.activity_logs.find_by(id: id) if type == "activity_log"
    when :reflection_entry then current_user.reflection_entries.find_by(id: id) if type == "reflection_entry"
    when :mini_cex_evaluation
      current_user.mini_cex_evaluations_as_student.submitted.find_by(id: id) if type == "mini_cex_evaluation"
    when :dops_evaluation
      current_user.dops_evaluations_as_student.submitted.find_by(id: id) if type == "dops_evaluation"
    when :wpba_observation
      current_user.wpba_observations_as_student.submitted.find_by(id: id) if type == "wpba_observation"
    when :epa_observation
      current_user.epa_observations.usable_as_evidence.find_by(id: id) if type == "epa_observation"
    when :evidence_source
      current_user.evidence_sources.find_by(id: id) if type == "evidence_source"
    end
  end

  def source_matches_requirement?(source, source_record, required_type)
    return false if source_record.blank?
    if source == :evidence_source
      return source_record.source_type == required_type if required_type.in?(%w[assessment wpba logbook reflection epa_observation external])
      return true if required_type.in?(%w[portfolio other])
      return false
    end

    case required_type
    when "assessment" then source == :assessment_instance
    when "wpba" then source.in?(%i[mini_cex_evaluation dops_evaluation wpba_observation])
      || (source == :assessment_instance && source_record.assessment_event.assessment_type == "cbd")
    when "logbook" then source == :activity_log
    when "reflection" then source == :reflection_entry
    when "epa_observation" then source == :epa_observation
    when "portfolio", "other" then true
    else false
    end
  end

  def initial_result(source_record)
    case source_record
    when EvidenceSource then source_record.validation_status == "validated" ? source_record.result.presence || "other" : "not_assessed"
    when AssessmentInstance then source_record.status == "scored" ? "other" : "not_assessed"
    when MiniCexEvaluation, DopsEvaluation then "other"
    when WpbaObservation then source_record.submitted? ? "other" : "not_assessed"
    when EpaObservation then source_record.status == "recorded" && (!source_record.safety_flag? || source_record.safety_resolved_at.present?) ? "other" : "not_assessed"
    when ReflectionEntry then "other"
    when ActivityLog then source_record.verified_at.present? ? "pass" : "not_assessed"
    else
      source_record.respond_to?(:activity_log) && source_record.activity_log&.verified_at.present? ? "pass" : "not_assessed"
    end
  end

  def requirement_for_current_student?(requirement)
    return false if current_user.study_program.blank?

    framework = requirement.competency_item&.competency_framework ||
      requirement.epa&.competency_framework ||
      requirement.blueprint_item&.blueprint_version&.competency_framework
    framework&.study_program_id == current_user.study_program_id
  end
end
