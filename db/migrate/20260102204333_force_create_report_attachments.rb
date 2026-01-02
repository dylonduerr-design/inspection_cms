class ForceCreateReportAttachments < ActiveRecord::Migration[7.1]
  def change
    # Only create the table if it doesn't exist (safety check)
    unless table_exists?(:report_attachments)
      create_table :report_attachments do |t|
        t.references :report, null: false, foreign_key: true
        t.string :caption
        t.timestamps
      end
    end
  end
end