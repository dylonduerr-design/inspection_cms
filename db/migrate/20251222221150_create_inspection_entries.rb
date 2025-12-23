class CreateInspectionEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :inspection_entries do |t|
      t.references :report, null: false, foreign_key: true
      t.references :bid_item, null: false, foreign_key: true
      t.decimal :quantity
      t.string :location
      t.text :notes

      t.timestamps
    end
  end
end
