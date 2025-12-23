json.extract! inspection_entry, :id, :report_id, :bid_item_id, :quantity, :location, :notes, :created_at, :updated_at
json.url inspection_entry_url(inspection_entry, format: :json)
