class FixArchitectureDebts < ActiveRecord::Migration[7.1]
  def change
    # --- 1. Fix Attachments ---
    drop_table :report_attachments if table_exists?(:report_attachments)

    # --- 2. Fix Identity (Reports) ---
    remove_column :reports, :inspector, :string

    # --- 3. Fix Activity Logs ---
    # STEP A: Delete existing logs first. 
    # (We can't keep them because they don't have a User ID, which is now required).
    execute "DELETE FROM activity_logs"

    # STEP B: Now it is safe to swap the columns
    remove_column :activity_logs, :user, :string
    add_reference :activity_logs, :user, null: false, foreign_key: true
  end
end