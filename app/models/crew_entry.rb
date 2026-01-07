class CrewEntry < ApplicationRecord
  belongs_to :report

  # Optional: Validations to keep data clean
  validates :contractor, presence: true
end