class InspectionEntry < ApplicationRecord
  belongs_to :report
  belongs_to :bid_item

  validates :quantity, presence: true
end