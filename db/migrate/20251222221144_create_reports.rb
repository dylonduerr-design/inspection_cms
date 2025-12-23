class CreateReports < ActiveRecord::Migration[7.1]
  def change
    create_table :reports do |t|
      t.string :dir_number
      t.date :inspection_date
      t.string :inspector
      t.references :project, null: false, foreign_key: true
      t.references :phase, null: false, foreign_key: true
      t.integer :status
      t.integer :result

      t.timestamps
    end
  end
end
