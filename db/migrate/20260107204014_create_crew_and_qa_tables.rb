class CreateCrewAndQaTables < ActiveRecord::Migration[7.1]
  def change
    # 1. Create CREW ENTRIES Table
    unless table_exists?(:crew_entries)
      create_table :crew_entries do |t|
        t.references :report, null: false, foreign_key: true
        t.string :contractor
        t.string :foreman
        t.string :superintendent
        t.integer :laborer_count
        t.integer :operator_count
        t.integer :survey_count
        t.integer :electrician_count
        t.text :notes

        t.timestamps
      end
    end

    # 2. Create QA ENTRIES Table
    unless table_exists?(:qa_entries)
      create_table :qa_entries do |t|
        t.references :report, null: false, foreign_key: true
        t.integer :qa_type, default: 0
        t.string :location
        t.integer :result, default: 0
        t.string :note

        t.timestamps
      end
    end
  end
end 