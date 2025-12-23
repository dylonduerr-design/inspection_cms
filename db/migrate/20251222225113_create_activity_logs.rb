class CreateActivityLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :activity_logs do |t|
      t.references :report, null: false, foreign_key: true
      t.string :user
      t.text :note

      t.timestamps
    end
  end
end
