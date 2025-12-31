class CreateReportAttachments < ActiveRecord::Migration[7.1]
  def change
    create_table :report_attachments do |t|
      t.references :report, null: false, foreign_key: true
      t.string :caption

      t.timestamps
    end
  end
end
