class BidItem < ApplicationRecord
  # 1. ASSOCIATIONS
  # It connects to a Spec, but acts as a standalone if needed (optional)
  belongs_to :spec_item, optional: true
  
  has_many :placed_quantities, dependent: :restrict_with_error
  
  # 2. VALIDATIONS
  validate :checklist_questions_must_be_array

  # 3. THE "TRAFFIC COP" (Smart Logic)
  # This determines which questions appear in the form
  def active_questions
    # A. If Bid Item has specific overrides, use them
    return checklist_questions if checklist_questions.present? && checklist_questions.any?
    
    # B. Otherwise, fallback to the Spec's questions
    return spec_item.checklist_questions if spec_item&.checklist_questions.present?
    
    # C. Default to empty
    []
  end

  # 4. VIRTUAL ATTRIBUTES (For the Form)
  # GETTER: Returns text for the textarea
  def questions_text
    active_questions.join("\n")
  end

  # SETTER: Saves text as array (Only saves to BidItem override)
  def questions_text=(text)
    self.checklist_questions = text.to_s.split("\n").map(&:strip).reject(&:blank?)
  end

  private

  def checklist_questions_must_be_array
    if checklist_questions.present? && !checklist_questions.is_a?(Array)
      errors.add(:checklist_questions, "must be a list of questions")
    end
  end
end