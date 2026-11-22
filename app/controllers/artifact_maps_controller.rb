# frozen_string_literal: true

# Read-only artifact map derived from a program's framework, blueprint and
# evidence requirements. It deliberately has no artifact master table.
class ArtifactMapsController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize AssessmentBlueprint, :artifact_map?
    @read_only = (current_user.active_role&.code || current_user.roles.first&.code) == "mahasiswa"
    @study_programs = if current_user.has_role?("superadmin")
      StudyProgram.ordered
    elsif @read_only
      StudyProgram.where(id: current_user.study_program_id)
    else
      StudyProgram.ordered.select { |program| current_user.has_permission?("curriculum.manage", study_program: program) }
    end
    @study_program = @study_programs.find_by(id: params[:study_program_id]) || @study_programs.first
    @framework = @study_program&.peta_kompetensi
    @blueprint = @study_program&.assessment_blueprint
    @blueprint_version = @blueprint&.current_version
    @blueprint_framework = @blueprint_version&.competency_framework
    @artifact_map = ArtifactMapBuilder.new(framework: @framework, blueprint_version: @blueprint_version).call
  end
end
