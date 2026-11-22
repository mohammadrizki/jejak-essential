# frozen_string_literal: true

class ReflectionEntryCompetencyTag < ApplicationRecord
  belongs_to :reflection_entry
  belongs_to :competency_item

  validates :competency_item_id, uniqueness: { scope: :reflection_entry_id }
end
