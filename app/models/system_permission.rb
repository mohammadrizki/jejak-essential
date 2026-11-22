# frozen_string_literal: true

class SystemPermission < ApplicationRecord
  has_many :role_permissions, dependent: :restrict_with_error
  has_many :roles, through: :role_permissions

  validates :key, presence: true, uniqueness: true,
    format: { with: /\A[a-z][a-z0-9_.]*\z/ }
  validates :name, presence: true
end
