# frozen_string_literal: true

class RolesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_superadmin!, except: :switch
  before_action :set_role, only: %i[edit update destroy]

  # Fitur "Ganti Peran": hanya menukar users.active_role_id, tanpa sesi/token
  # terpisah — cukup untuk akun multi-peran.
  def switch
    if current_user.switch_active_role!(params[:role_code])
      redirect_to dashboard_path, notice: "Peran aktif diganti ke #{current_user.active_role.name}."
    else
      redirect_back fallback_location: dashboard_path, alert: "Anda tidak memiliki peran itu."
    end
  end

  def index
    @roles = Role.includes(:system_permissions, :user_roles).order(:name)
    @permissions = SystemPermission.order(:key)
  end

  def new
    @role = Role.new
    load_permissions
  end

  def create
    @role = Role.new(role_params)
    save_permissions
    validate_permission_grants
    ActiveRecord::Base.transaction do
      @role.save!
      audit_role_change!("role.created", before: nil)
    end
    redirect_to roles_path, notice: "Peran #{@role.name} dibuat."
  rescue ActiveRecord::RecordInvalid
    load_permissions
    render :new, status: :unprocessable_entity
  end

  def edit
    load_permissions
  end

  def update
    before = role_snapshot
    @role.assign_attributes(role_params)
    if Role::BUILT_IN_CODES.include?(@role.code_in_database)
      @role.errors.add(:base, "Peran bawaan tidak dapat diubah identitasnya; kelola hak aksesnya saja.") if @role.will_save_change_to_code?
    end
    save_permissions
    validate_permission_grants
    if @role.errors.empty?
      ActiveRecord::Base.transaction do
        @role.save!
        audit_role_change!("role.updated", before: before)
      end
      return redirect_to roles_path, notice: "Peran #{@role.name} diperbarui."
    end
    load_permissions
    render :edit, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid
    load_permissions
    render :edit, status: :unprocessable_entity
  end

  def destroy
    if @role.system_role? || @role.user_roles.exists?
      return redirect_to roles_path, alert: "Peran bawaan atau yang masih diberikan kepada pengguna tidak dapat dihapus. Cabut assignment terlebih dahulu."
    end

    snapshot = role_snapshot
    ActiveRecord::Base.transaction do
      audit_role_change!("role.deleted", before: snapshot)
      @role.destroy!
    end
    redirect_to roles_path, notice: "Peran dihapus."
  end

  private

  def require_superadmin!
    return if current_user.has_role?("superadmin")

    redirect_to dashboard_path, alert: "Pengelolaan peran hanya tersedia bagi superadmin."
  end

  def set_role
    @role = Role.find(params[:id])
  end

  def role_params
    params.require(:role).permit(:code, :name)
  end

  def load_permissions
    @permissions = SystemPermission.order(:key)
    @permission_settings = @role.role_permissions.index_by { |item| item.system_permission_id }
  end

  def save_permissions
    ids = Array(params.dig(:role, :permission_ids)).reject(&:blank?).map(&:to_i).uniq
    @role.role_permissions.each { |grant| grant.mark_for_destruction unless ids.include?(grant.system_permission_id) }
    ids.each do |id|
      grant = @role.role_permissions.find { |item| item.system_permission_id == id } ||
        @role.role_permissions.build(system_permission_id: id)
      grant.scope_level = if grant.system_permission&.key == "templates.manage"
        "system"
      else
        params.dig(:role, :permission_scopes, id.to_s) == "system" ? "system" : "study_program"
      end
    end
  end

  def validate_permission_grants
    @role.role_permissions.each do |grant|
      next if grant.marked_for_destruction?
      next if grant.valid?

      label = grant.system_permission&.name || "Hak akses"
      @role.errors.add(:base, "#{label}: #{grant.errors.full_messages.to_sentence}")
    end
  end

  def role_snapshot
    { code: @role.code, name: @role.name,
      permissions: RolePermission.includes(:system_permission).where(role_id: @role.id).map do |grant|
        { key: grant.system_permission.key, scope: grant.scope_level }
      end.sort_by { |item| item[:key] } }
  end

  def audit_role_change!(event_key, before:)
    RbacAuditEvent.create!(actor_user: current_user, role_id: @role.id,
      event_key: event_key, details: { before: before, after: (event_key == "role.deleted" ? nil : role_snapshot) })
  end
end
