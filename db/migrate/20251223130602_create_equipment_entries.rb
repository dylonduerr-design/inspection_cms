class CreateEquipmentEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :equipment_entries do |t|
      t.references :report, null: false, foreign_key: true
      t.string :make_model
      t.decimal :hours

      t.timestamps
    end
  end
end
