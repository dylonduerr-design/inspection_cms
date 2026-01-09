class PlacedQuantity < ApplicationRecord
  belongs_to :report
  belongs_to :bid_item

  validates :bid_item, presence: true

  # SMART GETTER: Ensures this always returns a Hash/List, never a String
  def checklist_answers
    # 1. Get the raw value from the database
    value = super

    # 2. If it's already a real Hash (Postgres usually does this), return it
    return value if value.is_a?(Hash)

    # 3. If it's a String (SQLite or text column), parse it into a Hash
    if value.is_a?(String) && value.present?
      begin
        return JSON.parse(value)
      rescue JSON::ParserError
        return {} # Fallback if data is corrupted
      end
    end

    # 4. Default to empty hash if nil
    {}
  end
end