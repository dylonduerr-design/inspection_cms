class AddWeatherSummariesToReports < ActiveRecord::Migration[7.1]
  def change
    add_column :reports, :weather_summary_1, :string
    add_column :reports, :weather_summary_2, :string
    add_column :reports, :weather_summary_3, :string
  end
end
