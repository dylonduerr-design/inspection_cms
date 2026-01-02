class FixActivityLogUser < ActiveRecord::Migration[7.1]
  def change
    # 1. Remove the old 'string' column (the one causing the "unknown attribute" error)
    if column_exists?(:activity_logs, :user)
      remove_column :activity_logs, :user, :string
    end

    # 2. Add the User reference ONLY if it is missing
    unless column_exists?(:activity_logs, :user_id)
      add_reference :activity_logs, :user, foreign_key: true
    end
  end
end