class BidItem < ApplicationRecord
  has_many :inspection_entries
  
  # --- VALIDATION ---
  validate :checklist_questions_must_be_array

  # --- VIRTUAL ATTRIBUTE ---
  # This lets us use f.text_area :questions_text in the form!
  
  # 1. Convert the DB Array -> Text for the form (one question per line)
  def questions_text
    checklist_questions&.join("\n")
  end

  # 2. Convert the Form Text -> DB Array (splitting by new lines)
  def questions_text=(text)
    self.checklist_questions = text.split("\n").map(&:strip).reject(&:blank?)
  end

  private

  def checklist_questions_must_be_array
    if checklist_questions.present? && !checklist_questions.is_a?(Array)
      errors.add(:checklist_questions, "must be a list of questions")
    end
  end
end