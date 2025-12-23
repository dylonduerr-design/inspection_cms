class EquipmentEntry < ApplicationRecord
  belongs_to :report
  validates :make_model, presence: true
end