# app/models/checklist_entry.rb
class ChecklistEntry < ApplicationRecord
  belongs_to :report
  belongs_to :spec_item

  # MAESTRO FIX: Smart getter ensures we never get nil
  def checklist_answers
    # 1. Get raw value
    val = super
    
    # 2. Return immediately if it's already a Hash (Standard behavior)
    return val if val.is_a?(Hash)

    # 3. If it's a JSON string (rare but possible), parse it
    if val.is_a?(String) && val.present?
      begin
        return JSON.parse(val)
      rescue JSON::ParserError
        return {}
      end
    end

    # 4. Fallback to empty hash if nil
    {}
  end
end