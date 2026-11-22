# frozen_string_literal: true

class CompetencyFrameworkTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_template, only: %i[show duplicate copy edit update destroy]
  before_action :require_template_manager!, only: %i[new create copy edit update destroy]
  before_action :require_custom_template!, only: %i[edit update destroy]

  def index
    @templates = CompetencyFrameworkTemplate.all
  end

  def show
    @study_programs = manageable_programs
  end

  # `duplicate` tetap berarti menyalin template ke Peta Kompetensi program.
  def duplicate
    authorize CompetencyFramework, :create?
    target_program = StudyProgram.find(params.require(:study_program_id))
    unless current_user.has_role?("superadmin") || current_user.has_permission?("curriculum.manage", study_program: target_program)
      return redirect_to competency_framework_templates_path, alert: "Hak kelola kurikulum untuk program studi tujuan diperlukan."
    end

    framework = CompetencyFrameworkDuplicator.new(template: @template,
      study_program: target_program, name: params[:name].presence || @template.name).call
    redirect_to framework, notice: "Template disalin ke Peta Kompetensi sebagai draf independen versi #{framework.version}."
  rescue ActiveRecord::RecordInvalid => e
    @study_programs = manageable_programs
    @duplicate_errors = e.record.errors.full_messages
    render :show, status: :unprocessable_entity
  end

  def new
    @template = FrameworkTemplateRecord.new(source_name: "Adaptasi program studi", source_version: "1", template_version: "1.0.0", domains: [])
  end

  def create
    @template = FrameworkTemplateRecord.new
    assign_template_record_params
    return render(:new, status: :unprocessable_entity) if @template.errors.any?

    @template.created_by = current_user
    if @template.save
      redirect_to competency_framework_template_path(@template.key), notice: "Template ditambahkan ke pustaka."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    assign_template_record_params
    return render(:edit, status: :unprocessable_entity) if @template.errors.any?

    if @template.save
      redirect_to competency_framework_template_path(@template.key), notice: "Template diperbarui."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def copy
    attributes = %w[description source_name source_version template_version attribution education_stage domains]
      .index_with { |attribute| @template.public_send(attribute) }
    copy = FrameworkTemplateRecord.create!(attributes.merge(
      "name" => params[:name].presence || "Salinan #{@template.name}",
      "provenance" => { "kind" => "template_library_copy", "source_key" => @template.key,
        "source_name" => @template.name, "source_version" => @template.template_version, "copied_at" => Time.current.iso8601 },
      "created_by" => current_user
    ))
    redirect_to edit_competency_framework_template_path(copy.key), notice: "Salinan independen dibuat; silakan sesuaikan isinya."
  end

  def destroy
    @template.destroy!
    redirect_to competency_framework_templates_path, notice: "Template dihapus dari pustaka.", status: :see_other
  rescue ActiveRecord::RecordNotDestroyed => e
    redirect_to competency_framework_template_path(@template.key), alert: e.record.errors.full_messages.to_sentence
  end

  private

  def set_template
    @template = CompetencyFrameworkTemplate.find_by_key(params[:id])
    raise ActiveRecord::RecordNotFound if @template.blank?
  end

  def require_template_manager!
    return if current_user.has_system_permission?("templates.manage")

    redirect_to competency_framework_templates_path, alert: "Hak akses kelola pustaka template diperlukan."
  end

  def require_custom_template!
    return if @template.is_a?(FrameworkTemplateRecord)

    redirect_to competency_framework_template_path(@template.key), alert: "Template bawaan tidak dapat diubah langsung. Duplikasi template untuk membuat salinan yang dapat disunting."
  end

  def manageable_programs
    return StudyProgram.ordered if current_user.has_role?("superadmin")

    StudyProgram.ordered.select { |program| current_user.has_permission?("curriculum.manage", study_program: program) }
  end

  def assign_template_record_params
    attributes = params.require(:framework_template_record).permit(:name, :description, :source_name,
      :source_version, :template_version, :attribution, :education_stage, :domains_json)
    @template.domains_json = attributes[:domains_json].to_s
    domains = JSON.parse(attributes[:domains_json].presence || "[]")
    @template.assign_attributes(attributes.except(:domains_json).to_h.merge("domains" => domains))
  rescue JSON::ParserError => e
    @template.errors.add(:domains, "JSON tidak valid: #{e.message}")
  end
end
