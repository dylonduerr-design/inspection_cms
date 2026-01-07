class BidItem < ApplicationRecord
  # SAFETY: Prevent deleting a Bid Item if it is used in existing reports
  has_many :inspection_entries, dependent: :restrict_with_error
  
  # --- VALIDATION ---
  validate :checklist_questions_must_be_array

  # --- VIRTUAL ATTRIBUTE ---
  # This acts as a translator between the Form (Text Area) and the Database (Array)
  
  # 1. GETTER: Convert DB Array -> Text (One question per line)
  def questions_text
    checklist_questions&.join("\n")
  end

  # 2. SETTER: Convert Form Text -> DB Array (Splitting by new lines)
  def questions_text=(text)
    # .to_s ensures safety if nil is passed
    self.checklist_questions = text.to_s.split("\n").map(&:strip).reject(&:blank?)
  end

  private

  def checklist_questions_must_be_array
    # Ensure we never accidentally save a string into the JSON array column
    if checklist_questions.present? && !checklist_questions.is_a?(Array)
      errors.add(:checklist_questions, "must be a list of questions")
    end
  end
end