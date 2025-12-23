class AddDetailsToReports < ActiveRecord::Migration[7.1]
  def change
    add_column :reports, :shift_start, :string
    add_column :reports, :shift_end, :string
    add_column :reports, :weather, :string
    add_column :reports, :temperature, :integer
    add_column :reports, :station_start, :string
    add_column :reports, :station_end, :string
    add_column :reports, :contractor, :string
    add_column :reports, :plan_sheet, :string
    add_column :reports, :relevant_docs, :string
    add_column :reports, :deficiency_status, :integer
    add_column :reports, :deficiency_desc, :text
    add_column :reports, :traffic_control, :integer
    add_column :reports, :environmental, :integer
    add_column :reports, :security, :integer
    add_column :reports, :safety_incident, :integer
    add_column :reports, :safety_desc, :text
    add_column :reports, :commentary, :text
    add_column :reports, :qa_activity, :boolean
    add_column :reports, :qa_bid_item_id, :integer
    add_column :reports, :qa_type, :integer
    add_column :reports, :qa_result, :integer
    add_column :reports, :foreman, :string
    add_column :reports, :laborer_count, :integer
    add_column :reports, :operator_count, :integer
    add_column :reports, :survey_count, :integer
  end
end
