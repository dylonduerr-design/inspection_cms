class ExtractQaEntries < ActiveRecord::Migration[7.1]
  def change
    # 1. Create the new QA Table
    create_table :qa_entries do |t|
      t.references :report, null: false, foreign_key: true
      t.integer :qa_type        # "Test Performed" (Enum)
      t.string :location        # "Location"
      t.integer :result         # "Pass/Fail" (Enum)
      t.string :note            # "Remarks"
      
      t.timestamps
    end

    # 2. Clean up Report table (Remove the old single-entry fields)
    remove_column :reports, :qa_type, :integer
    remove_column :reports, :qa_result, :integer
    remove_column :reports, :qa_bid_item_id, :integer
    remove_column :reports, :qa_activity, :boolean
  end
end

