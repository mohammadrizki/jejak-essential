# frozen_string_literal: true

class EvidenceRecordsController < ApplicationController
  before_action :authenticate_user!

  def create
    requirement = EvidenceRequirement.find(params[:evidence_requirement_id])
    unless requirement_for_current_student?(requirement)
      return redirect_to portfolio_path, alert: "Syarat bukti ini bukan milik program studi Anda."
    end
    source = owned_source
    source_record = owned_source_record
    return redirect_back fallback_location: portfolio_path, alert: "Pilih bukti yang Anda miliki." if source.blank? || source_record.blank?
    unless source_matches_requirement?(source, requirement.source_type)
      return redirect_back fallback_location: portfolio_path, alert: "Jenis bukti tidak sesuai dengan syarat ini."
    end

    record = requirement.evidence_records.new(
      source => source_record,
      evidence_date: params.dig(:evidence_record, :evidence_date).presence || Date.current,
      result: initial_result(source_record),
      score: source == :assessment_instance ? source_record.score : nil,
      metadata: { submitted_by_student_id: current_user.id }
    )
    if record.save
      redirect_to portfolio_path, notice: "Bukti aktual ditautkan ke syarat."
    else
      redirect_to portfolio_path, alert: record.errors.full_messages.to_sentence
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
    end
  end

  def source_matches_requirement?(source, required_type)
    case required_type
    when "assessment" then source == :assessment_instance
    when "logbook" then source == :activity_log
    when "reflection" then source == :reflection_entry
    when "portfolio", "other" then true
    else false
    end
  end

  def initial_result(source_record)
    case source_record
    when AssessmentInstance then source_record.status == "scored" ? "other" : "not_assessed"
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
