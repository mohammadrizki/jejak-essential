# frozen_string_literal: true

class AssessmentFormSubmissionsController < ApplicationController
  before_action :authenticate_user!

  def index
    @submissions = policy_scope(AssessmentFormSubmission).includes(:assessment_form_template).recent.page(params[:page])
  end

  def show
    @submission = AssessmentFormSubmission.find(params[:id])
    authorize @submission
  end

  def new
    @template = AssessmentFormTemplate.active.find(params[:assessment_form_template_id])
    authorize @template, :show?
    @submission = @template.assessment_form_submissions.build(subject_user_id: params[:subject_user_id].presence)
    load_subject_candidates
  end

  def create
    @template = AssessmentFormTemplate.active.find(params[:assessment_form_template_id])
    authorize @template, :show?
    requested_subject_id = params.dig(:assessment_form_submission, :subject_user_id)
    if requested_subject_id.present? && !allowed_subject_users.exists?(id: requested_subject_id)
      return redirect_to assessment_form_template_path(@template),
        alert: "Subjek formulir berada di luar program studi yang dapat Anda kelola."
    end

    @submission = @template.assessment_form_submissions.build(submission_params)
    @submission.respondent = current_user
    @submission.submitted_at = Time.current
    build_answers

    if @submission.save
      redirect_to assessment_form_template_path(@template), notice: "Terima kasih, jawaban Anda tersimpan."
    else
      load_subject_candidates
      render :new, status: :unprocessable_entity
    end
  end

  private

  # Kandidat subjek mengikuti konteks, bukan selalu dosen: rubrik yang dipakai
  # menilai mahasiswa (mis. dari lembar penguji) harus bisa memilih mahasiswa.
  # Subjek yang dipilih lewat ?subject_user_id= selalu ikut di daftar meski
  # tidak berperan itu. Peran disaring lewat subquery, bukan joins+distinct:
  # Relation#or menolak relasi yang strukturnya berbeda, dan dulu setiap
  # ?subject_user_id= (sah atau tidak) berakhir ArgumentError → galat 500.
  def load_subject_candidates
    codes = params[:subject_role].to_s == "mahasiswa" ? %w[mahasiswa] : %w[dosen preseptor]
    role_candidate_ids = User.active_accounts.joins(:roles).where(roles: { code: codes }).select(:id)
    scope = allowed_subject_users.where(id: role_candidate_ids)
    if params[:subject_user_id].present?
      scope = scope.or(allowed_subject_users.where(id: params[:subject_user_id]))
    end
    @subject_candidates = scope.order(:full_name)
  end

  def allowed_subject_users
    return User.active_accounts if current_user.has_role?("superadmin")

    program_ids = @template.study_program_id ? [@template.study_program_id] : []
    return User.active_accounts.where(study_program_id: program_ids) if
      current_user.permitted_for_program?(@template.study_program, "curriculum.manage")

    User.none
  end

  def submission_params
    params.require(:assessment_form_submission).permit(:subject_user_id, :subject_label)
  end

  # Jawaban dikirim sebagai answers[field_id] = value dari form, bukan
  # nested_attributes standar (field_id tidak diketahui sebelumnya karena
  # pertanyaan dinamis per template).
  # Jawaban dibangun untuk SETIAP pertanyaan template, bukan hanya yang
  # parameternya terkirim: radio yang tidak dipilih tidak mengirim apa pun,
  # dan dulu itu membuat pertanyaan wajib lolos tanpa jawaban.
  def build_answers
    submitted = params[:answers] || {}
    @template.assessment_form_fields.ordered.each do |field|
      @submission.assessment_form_answers.build(assessment_form_field: field, value: submitted[field.id.to_s])
    end
  end
end
