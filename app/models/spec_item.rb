class SpecItem < ApplicationRecord
  # This Spec governs many Bid Items
  has_many :bid_items
  
  # Validations to keep data clean
  validates :code, presence: true, uniqueness: true
end