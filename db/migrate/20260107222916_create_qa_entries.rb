class CreateQaEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :qa_entries do |t|
      t.references :report, null: false, foreign_key: true
      t.integer :qa_type
      t.string :location
      t.integer :result
      t.string :remarks

      t.timestamps
    end
  end
end
