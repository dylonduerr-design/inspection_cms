class ActivityLog < ApplicationRecord
  belongs_to :report
  validates :note, presence: true
end