# frozen_string_literal: true

class ProfilesController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
  end

  def edit
    @user = current_user
  end

  def update
    if current_user.update(profile_params)
      redirect_to profile_path, notice: "Profil berhasil diperbarui."
    else
      @user = current_user
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    permitted = params.require(:user).permit(
      :full_name, :avatar, :study_program_id,
      :identifier_number, :phone, :gender, :birth_place, :birth_date, :address,
      :cohort_year, :work_unit, :position, :profession_category, :specialization
    )
    # Prodi menentukan batas akses akademik. Selain admin, pengguna tidak
    # boleh memindahkan akun sendiri ke program studi lain lewat profil.
    permitted.delete(:study_program_id) unless current_user.has_role?("admin")
    permitted
  end
end
