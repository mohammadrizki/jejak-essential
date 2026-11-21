# frozen_string_literal: true

# Read-only artifact map derived from a program's framework, blueprint and
# evidence requirements. It deliberately has no artifact master table.
class ArtifactMapsController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize AssessmentBlueprint
    @study_programs = StudyProgram.ordered
    @study_program = @study_programs.find_by(id: params[:study_program_id]) || @study_programs.first
    @framework = @study_program&.peta_kompetensi
    @blueprint = @study_program&.assessment_blueprint
    @blueprint_version = @blueprint&.current_version
    @indicators = @framework ? @framework.competency_indicators.includes(:competency_item, :evidence_requirements).order(:position, :code) : CompetencyIndicator.none
    @mappings_by_code = if @blueprint_version
      mappings = BlueprintItemCompetency.where(blueprint_item_id: @blueprint_version.blueprint_items.select(:id))
        .includes(:competency_item, :competency_indicator, blueprint_item: :evidence_requirements)
      mappings.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |mapping, grouped|
        key = [ mapping.competency_item.code, mapping.competency_indicator&.code ]
        grouped[key] << mapping
      end
    else
      {}
    end
  end
end
