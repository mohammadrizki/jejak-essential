# frozen_string_literal: true

# Guards lifecycle actions against downstream academic references. Configuration
# such as manual Evidence Requirements is retained when unpublishing; historical
# evidence and decisions always require a new framework version instead.
class CompetencyFrameworkLifecycle
  class Blocked < StandardError
    attr_reader :reasons

    def initialize(reasons)
      @reasons = reasons
      super(reasons.to_sentence)
    end
  end

  def initialize(framework)
    @framework = framework
  end

  def unpublish_blockers
    @unpublish_blockers ||= begin
      blockers = dependency_counts.reject { |_label, count| count.zero? }.map(&:first)
      if @framework.status.in?(%w[published archived])
        other_drafts = @framework.study_program.framework_versions.where(status: "draft").where.not(id: @framework.id).count
        blockers << "draf koreksi pada program studi (#{other_drafts})" if other_drafts.positive?
      end
      blockers
    end
  end

  def deletable?
    @framework.status.in?(%w[draft archived]) && deletion_blockers.empty?
  end

  def deletion_blockers
    @deletion_blockers ||= begin
      blockers = unpublish_blockers.dup
      version_count = EvidenceRequirementVersion.where(evidence_requirement_id: requirements.select(:id)).count
      blockers << "snapshot versi Bukti yang Diharapkan yang tetap (#{version_count})" if version_count.positive?
      blockers
    end
  end

  def unpublishable?
    @framework.status == "published" && unpublish_blockers.empty?
  end

  def retained_configuration_count
    requirements.count
  end

  def unpublish!
    raise Blocked, ["framework bukan versi published"] unless @framework.status == "published"
    raise Blocked, unpublish_blockers if unpublish_blockers.any?

    CompetencyFramework.transaction do
      @framework.archive_unpublished!
    end
  end

  def destroy!
    raise Blocked, ["hanya framework draf atau arsip tanpa dependensi historis yang dapat dihapus"] unless @framework.status.in?(%w[draft archived])
    raise Blocked, deletion_blockers if deletion_blockers.any?

    CompetencyFramework.transaction do
      @framework.prepare_for_safe_deletion!
      requirements.each do |requirement|
        if requirement.versions.exists?
          raise Blocked, ["snapshot versi Bukti yang Diharapkan yang tetap"]
        end
        requirement.destroy!
      end

      item_ids = @framework.competency_items.select(:id)
      CompetencyProgression.where(source_competency_id: item_ids)
        .or(CompetencyProgression.where(target_competency_id: item_ids)).delete_all

      @framework.epas.each(&:destroy!)
      @framework.competency_items.each do |item|
        item.competency_indicators.each(&:destroy!)
      end
      @framework.destroy!
    end
  end

  private

  def item_ids = @framework.competency_items.select(:id)
  def epa_ids = @framework.epas.select(:id)

  def requirements
    @requirements ||= EvidenceRequirement.where(competency_item_id: item_ids)
      .or(EvidenceRequirement.where(competency_indicator_id: @framework.competency_indicators.select(:id)))
      .or(EvidenceRequirement.where(epa_id: epa_ids)).distinct
  end

  def dependency_counts
    [
      ["versi blueprint yang merujuk peta kompetensi (#{@framework.blueprint_versions.count})", @framework.blueprint_versions.count],
      ["rekaman bukti mahasiswa (#{EvidenceRecord.where(evidence_requirement_id: requirements.select(:id)).count})",
        EvidenceRecord.where(evidence_requirement_id: requirements.select(:id)).count],
      ["capaian kompetensi mahasiswa (#{CompetencyAttainment.where(competency_item_id: item_ids).count})",
        CompetencyAttainment.where(competency_item_id: item_ids).count],
      ["keputusan entrustment (#{decisions.count})", decisions.count],
      ["observasi EPA (#{EpaObservation.where(epa_id: epa_ids).count})", EpaObservation.where(epa_id: epa_ids).count],
      ["dossier promosi EPA (#{EpaPromotion.where(epa_id: epa_ids).count})", EpaPromotion.where(epa_id: epa_ids).count],
      ["pemetaan kompetensi blueprint (#{AssessmentBlueprintMapping.where(competency_item_id: item_ids).count})",
        AssessmentBlueprintMapping.where(competency_item_id: item_ids).count],
      ["dimensi asesmen yang dipetakan (#{AssessmentDimension.where(competency_item_id: item_ids).count})",
        AssessmentDimension.where(competency_item_id: item_ids).count],
      ["field instrumen asesmen yang dipetakan (#{AssessmentFormField.where(competency_item_id: item_ids).count})",
        AssessmentFormField.where(competency_item_id: item_ids).count],
      ["tag kompetensi pada logbook (#{ActivityLogCompetencyTag.where(competency_item_id: item_ids).count})",
        ActivityLogCompetencyTag.where(competency_item_id: item_ids).count],
      ["tag kompetensi pada refleksi (#{ReflectionEntryCompetencyTag.where(competency_item_id: item_ids).count})",
        ReflectionEntryCompetencyTag.where(competency_item_id: item_ids).count]
    ]
  end

  def decisions
    EntrustmentDecision.where(competency_item_id: item_ids).or(EntrustmentDecision.where(epa_id: epa_ids))
  end
end
