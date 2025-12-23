class CreateBidItems < ActiveRecord::Migration[7.1]
  def change
    create_table :bid_items do |t|
      t.string :code
      t.string :description
      t.string :unit

      t.timestamps
    end
  end
end
