# frozen_string_literal: true

class RbacAuditEvent < ApplicationRecord
  belongs_to :actor_user, class_name: "User", optional: true
  belongs_to :subject_user, class_name: "User", optional: true

  validates :event_key, presence: true

  before_update { throw :abort }
  before_destroy { throw :abort }
end
