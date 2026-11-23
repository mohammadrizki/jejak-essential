# frozen_string_literal: true

# Konfigurasi → Pengguna: daftar, sunting peran/prodi, reset kata sandi ke
# bawaan, dan impor CSV. Gerbangnya has_role?("admin") — sama dengan policy
# halaman konfigurasi lain, bukan peran aktif.
class Admin::UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :require_superadmin!, only: %i[import import_create registration]
  before_action :set_user, only: %i[edit update destroy reset_password confirm_email deactivate reactivate]
  before_action :reject_own_account, only: %i[destroy deactivate]

  def index
    @query = params[:q].to_s.strip
    @role_code = params[:role].presence
    @study_program_id = params[:study_program_id].presence

    scope = User.includes(:roles, :study_program, :active_role).order(:full_name)
    if @query.present?
      like = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      scope = scope.where("full_name ILIKE :q OR email ILIKE :q", q: like)
    end
    scope = scope.joins(:roles).where(roles: { code: @role_code }).distinct if @role_code
    scope = scope.where(study_program_id: @study_program_id) if @study_program_id

    @study_programs = manageable_programs
    @manageable_program_ids = @study_programs.map(&:id)
    scope = scope.where(study_program_id: @manageable_program_ids) unless current_user.has_role?("superadmin")
    @users = scope.page(params[:page]).per(25)
    @roles = Role.order(:name)
    @registration_open = AppSetting.registration_open?
  end

  def edit
    load_form_collections
  end

  def update
    role_ids = Array(params.dig(:user, :role_ids)).reject(&:blank?).map(&:to_i)
    original_program_id = @user.study_program_id
    if role_ids.empty?
      @user.errors.add(:base, "Pengguna harus memiliki minimal satu peran.")
      load_form_collections
      return render :edit, status: :unprocessable_entity
    end
    if Role.where(id: role_ids).count != role_ids.uniq.size
      @user.errors.add(:base, "Ada peran yang tidak dikenal.")
      load_form_collections
      return render :edit, status: :unprocessable_entity
    end

    @user.assign_attributes(user_params)
    unless current_user.has_role?("superadmin") ||
        (current_user.has_permission?("users.manage", study_program: StudyProgram.find_by(id: original_program_id)) &&
          current_user.has_permission?("users.manage", study_program: @user.study_program))
      @user.errors.add(:base, "Anda tidak dapat mengelola pengguna di program studi tujuan.")
      load_form_collections
      return render :edit, status: :unprocessable_entity
    end
    if User.program_required_for_roles?(Role.where(id: role_ids).pluck(:code)) && @user.study_program_id.nil?
      @user.errors.add(:base, "Kaprodi wajib punya Program Studi: itulah prodi binaannya.")
      load_form_collections
      return render :edit, status: :unprocessable_entity
    end

    if role_ids.include?(Role.find_by(code: "superadmin")&.id) && !current_user.has_role?("superadmin")
      @user.errors.add(:base, "Hanya superadmin yang dapat memberikan peran superadmin.")
      load_form_collections
      return render :edit, status: :unprocessable_entity
    end
    superadmin_role_id = Role.find_by(code: "superadmin")&.id
    if @user.user_roles.exists?(role_id: superadmin_role_id) && !role_ids.include?(superadmin_role_id) &&
        UserRole.joins(:role).where(roles: { code: "superadmin" }).count <= 1
      @user.errors.add(:base, "Superadmin terakhir tidak dapat dicabut. Bootstrap superadmin pengganti terlebih dahulu.")
      load_form_collections
      return render :edit, status: :unprocessable_entity
    end

    scope_errors = []
    role_ids.each do |role_id|
      role = Role.find_by(id: role_id)
      next unless role
      level = params.dig(:user, :role_scopes, role_id.to_s).presence || (role.code == "admin" ? "study_program" : "system")
      program_ids = Array(params.dig(:user, :role_program_ids, role_id.to_s)).reject(&:blank?).map(&:to_i)
      if !%w[system study_program].include?(level)
        scope_errors << "Cakupan peran #{role.name} tidak valid."
      elsif %w[admin superadmin].include?(role.code) && !current_user.has_role?("superadmin")
        scope_errors << "Hanya superadmin yang dapat memberikan peran #{role.name}."
      elsif role.code == "admin" && level == "system"
        scope_errors << "Admin harus dibatasi pada program studi; gunakan superadmin untuk akses sistem."
      elsif level == "study_program" && program_ids.empty?
        scope_errors << "Pilih program studi untuk peran #{role.name}."
      elsif level == "study_program" && program_ids.any? { |program_id| StudyProgram.find_by(id: program_id).nil? }
        scope_errors << "Program studi pada cakupan peran tidak dikenal."
      elsif level == "study_program" && !current_user.has_role?("superadmin") && program_ids.any? do |program_id|
          !current_user.has_permission?("users.manage", study_program: StudyProgram.find_by(id: program_id))
        end
        scope_errors << "Anda tidak berwenang memberikan peran pada salah satu program studi yang dipilih."
      end
    end
    proposed_scope_ids = role_ids.flat_map do |role_id|
      Array(params.dig(:user, :role_program_ids, role_id.to_s)).reject(&:blank?).map(&:to_i)
    end
    existing_scope_ids = @user.user_roles.filter_map(&:study_program_id)
    affected_program_ids = (proposed_scope_ids + existing_scope_ids + [original_program_id, @user.study_program_id]).compact.uniq
    grants_changed = begin
      existing = @user.user_roles.map { |grant| [grant.role_id, grant.scope_level, grant.study_program_id] }.sort
      proposed = role_ids.flat_map do |role_id|
        role = Role.find_by(id: role_id)
        next [] unless role
        level = params.dig(:user, :role_scopes, role_id.to_s).presence || (role.code == "admin" ? "study_program" : "system")
        if level == "system"
          [[role.id, level, nil]]
        else
          Array(params.dig(:user, :role_program_ids, role_id.to_s)).reject(&:blank?).map do |program_id|
            [role.id, level, program_id.to_i]
          end
        end
      end.sort
      existing != proposed
    end
    if grants_changed && !current_user.has_role?("superadmin")
      unless affected_program_ids.all? do |program_id|
        program = StudyProgram.find_by(id: program_id)
        program && current_user.has_permission?("roles.assign", study_program: program)
      end
        scope_errors << "Hak akses untuk memberikan peran pada setiap program studi terkait diperlukan."
      end
      if role_ids.any? do |role_id|
        role = Role.find_by(id: role_id)
        role && params.dig(:user, :role_scopes, role_id.to_s) == "system" && role.role_permissions.where(scope_level: "system").exists?
      end
        scope_errors << "Peran dengan hak akses sistem hanya dapat diberikan oleh superadmin."
      end
    end
    if scope_errors.any?
      scope_errors.each { |message| @user.errors.add(:base, message) }
      load_form_collections
      return render :edit, status: :unprocessable_entity
    end

    old_grants = role_grant_snapshot(@user)
    User.transaction do
      @user.save!
      selected_roles = Role.where(id: role_ids).index_by(&:id)
      desired_grants = []
      role_ids.each do |id|
        role = selected_roles.fetch(id)
        next if role.code == "superadmin" && !current_user.has_role?("superadmin")

        scope = params.dig(:user, :role_scopes, id.to_s).presence || (role.code == "admin" ? "study_program" : "system")
        if scope == "system"
          desired_grants << [role, scope, nil]
        else
          Array(params.dig(:user, :role_program_ids, id.to_s)).reject(&:blank?).each do |program_id|
            desired_grants << [role, scope, StudyProgram.find(program_id)]
          end
        end
      end
      @user.user_roles.each do |grant|
        desired = desired_grants.any? do |role, scope, program|
          grant.role_id == role.id && grant.scope_level == scope && grant.study_program_id == program&.id
        end
        grant.destroy! unless desired
      end
      desired_grants.each do |role, scope, program|
        @user.user_roles.find_or_create_by!(role: role, scope_level: scope, study_program: program)
      end
      StudentProgramEnrollmentBootstrap.ensure_current!(user: @user, by: current_user)
      new_grants = role_grant_snapshot(@user)
      if old_grants != new_grants
        RbacAuditEvent.create!(actor_user: current_user, subject_user: @user,
          event_key: "user_roles.changed", details: { before: old_grants, after: new_grants })
      end
      @user.update!(active_role_id: role_ids.first) unless role_ids.include?(@user.active_role_id)
    end
    redirect_to admin_users_path, notice: "Data #{@user.full_name} diperbarui."
  rescue ActiveRecord::RecordInvalid
    load_form_collections
    render :edit, status: :unprocessable_entity
  end

  # Admin yang mereset kata sandi sekaligus menjamin akunnya — email ikut
  # dikonfirmasi dan kunci (terlalu banyak salah kata sandi) dibuka, kalau
  # tidak pengguna tetap tertahan walau kata sandinya benar. Kata sandinya
  # sementara & acak, ditampilkan sekali lewat flash ke admin, dan wajib
  # diganti pengguna saat masuk.
  def reset_password
    temporary = @user.assign_temporary_password
    @user.confirmed_at ||= Time.current
    @user.locked_at = nil
    @user.failed_attempts = 0
    @user.save!
    flash[:temporary_password] = temporary
    redirect_to edit_admin_user_path(@user), notice: "Kata sandi #{@user.full_name} direset ke kata sandi sementara.", status: :see_other
  end

  def confirm_email
    @user.confirm unless @user.confirmed?
    redirect_to edit_admin_user_path(@user), notice: "Email #{@user.email} ditandai terkonfirmasi.", status: :see_other
  end

  def deactivate
    @user.update_column(:deactivated_at, Time.current)
    redirect_to edit_admin_user_path(@user), notice: "Akun #{@user.full_name} dinonaktifkan.", status: :see_other
  end

  def reactivate
    @user.update_column(:deactivated_at, nil)
    redirect_to edit_admin_user_path(@user), notice: "Akun #{@user.full_name} diaktifkan kembali.", status: :see_other
  end

  # Hanya akun tanpa rekam jejak; lihat User#deletable?.
  def destroy
    unless @user.deletable?
      return redirect_to edit_admin_user_path(@user), status: :see_other,
                         alert: "Akun #{@user.full_name} sudah punya rekam jejak dan tidak dapat dihapus. Nonaktifkan saja."
    end

    @user.destroy!
    redirect_to admin_users_path, notice: "Akun #{@user.full_name} dihapus.", status: :see_other
  end

  def registration
    AppSetting.set_registration_open!(params[:open], by: current_user)
    state = AppSetting.registration_open? ? "dibuka" : "ditutup"
    redirect_to admin_users_path, notice: "Pendaftaran mandiri #{state}.", status: :see_other
  end

  def import; end

  def import_create
    file = params[:file]
    if file.blank?
      redirect_to import_admin_users_path, alert: "Pilih berkas CSV terlebih dahulu."
      return
    end

    @result = UserCsvImporter.new(file).call
    render :import, status: (@result.errors.any? && @result.created.empty? && @result.updated.empty? ? :unprocessable_entity : :ok)
  end

  private

  def require_admin!
    return if current_user.has_role?("superadmin")
    program = if params[:id].present?
      User.find_by(id: params[:id])&.study_program
    else
      StudyProgram.find_by(id: params[:study_program_id]) || manageable_programs.first
    end
    return if program.present? && current_user.has_permission?("users.manage", study_program: program)

    redirect_to dashboard_path, alert: "Anda tidak memiliki hak akses pengelolaan pengguna pada lingkup ini."
  end

  def require_superadmin!
    return if current_user.has_role?("superadmin")

    redirect_to dashboard_path, alert: "Operasi ini memerlukan superadmin sistem."
  end

  def set_user
    @user = User.find(params[:id])
  end

  # Supaya admin tidak mengunci dirinya sendiri, dan selalu tersisa satu admin aktif.
  def reject_own_account
    return unless @user == current_user

    redirect_to edit_admin_user_path(@user), alert: "Akun yang sedang Anda pakai tidak dapat dinonaktifkan atau dihapus.", status: :see_other
  end

  def load_form_collections
    @roles = current_user.has_role?("superadmin") ? Role.order(:name) :
      Role.where.not(code: "superadmin").or(Role.where(id: @user.role_ids)).order(:name)
    @study_programs = manageable_programs
  end

  def manageable_programs
    return StudyProgram.ordered.to_a if current_user.has_role?("superadmin")

    StudyProgram.ordered.select { |program| current_user.has_permission?("users.manage", study_program: program) }
  end

  def role_grant_snapshot(user)
    UserRole.includes(:role, :study_program).where(user_id: user.id).map do |grant|
      { role: grant.role.code, scope: grant.scope_level, study_program_id: grant.study_program_id }
    end.sort_by { |entry| [entry[:role], entry[:scope], entry[:study_program_id].to_i] }
  end

  def user_params
    params.require(:user).permit(:full_name, :study_program_id)
  end
end
