class ActivityLog < ApplicationRecord
  belongs_to :report
  
  # --- ADD THIS MISSING LINE ---
  belongs_to :user
  # -----------------------------
  
  validates :note, presence: true
end