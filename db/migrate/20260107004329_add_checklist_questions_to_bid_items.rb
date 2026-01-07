class AddChecklistQuestionsToBidItems < ActiveRecord::Migration[7.1]
  def change
    add_column :bid_items, :checklist_questions, :jsonb
  end
end
