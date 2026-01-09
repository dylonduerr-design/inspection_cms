class ChecklistEntry < ApplicationRecord
  belongs_to :report
  belongs_to :spec_item
end
