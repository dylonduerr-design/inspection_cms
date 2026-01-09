class RenameInspectionEntriesToPlacedQuantities < ActiveRecord::Migration[7.1]
  def change
    rename_table :placed_quantities, :placed_quantities
  end
end