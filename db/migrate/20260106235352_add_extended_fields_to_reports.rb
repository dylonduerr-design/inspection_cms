class AddExtendedFieldsToReports < ActiveRecord::Migration[7.1]
  def change
    # --- 1. Date Split ---
    rename_column :reports, :inspection_date, :start_date
    add_column :reports, :end_date, :date

    # --- 2. Weather Trio (3x fields) ---
    # Keeping existing temp but adding the trios. 
    # If you want to migrate old data later, we can, but for now we just add columns.
    add_column :reports, :temp_1, :integer
    add_column :reports, :temp_2, :integer
    add_column :reports, :temp_3, :integer

    add_column :reports, :wind_1, :string
    add_column :reports, :wind_2, :string
    add_column :reports, :wind_3, :string

    add_column :reports, :precip_1, :string
    add_column :reports, :precip_2, :string
    add_column :reports, :precip_3, :string

    # --- 3. New Report Level Checklist Items ---
    # 0=N/A, 1=Yes, 2=No
    add_column :reports, :air_ops_coordination, :integer, default: 0
    add_column :reports, :swppp_controls, :integer, default: 0

    # --- 4. Conditional Text Fields ---
    add_column :reports, :additional_activities, :text
    add_column :reports, :additional_info, :text

    # --- 5. Bid Item Specific Checklist System ---
    # The Template: Stores the list of questions ["Q1", "Q2"]
    add_column :bid_items, :checklist_questions, :jsonb, default: [] 
    
    # The Answers: Stores the user's input {"Q1": "Yes", "Q2": "No"}
    add_column :inspection_entries, :checklist_answers, :jsonb, default: {}
  end
end