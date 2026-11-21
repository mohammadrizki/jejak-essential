# frozen_string_literal: true

class AssessmentMethod < ApplicationRecord
  has_many :blueprint_items, dependent: :restrict_with_error
  has_many :evidence_requirements, dependent: :restrict_with_error

  validates :code, :name, presence: true
  validates :code, uniqueness: true
end
