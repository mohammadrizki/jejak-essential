# frozen_string_literal: true

# Dasar controller Konfigurasi khusus admin. Controller admin yang lebih lama
# masing-masing menulis require_admin! sendiri; yang baru cukup mewarisi ini.
class Admin::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  private

  def require_admin!
    return if current_user.has_role?("superadmin")

    redirect_to dashboard_path, alert: "Data master tingkat sistem hanya dapat dikelola superadmin."
  end
end
