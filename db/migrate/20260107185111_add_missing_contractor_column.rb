class AddMissingContractorColumn < ActiveRecord::Migration[7.1]
  def change
    # Check if column exists first to avoid crashing if it's already there
    unless column_exists?(:equipment_entries, :contractor)
      add_column :equipment_entries, :contractor, :string
    end
  end
end