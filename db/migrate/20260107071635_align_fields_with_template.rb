class AlignFieldsWithTemplate < ActiveRecord::Migration[7.1]
  def change
    # 1. Update Reports (Crew Section)
    add_column :reports, :superintendent, :string
    add_column :reports, :electrician_count, :integer

    # 2. Update Equipment Entries
    add_column :equipment_entries, :quantity, :integer, default: 1

    # 3. Update Inspection Entries (Bid Items)
    remove_column :inspection_entries, :location, :string
  end
end