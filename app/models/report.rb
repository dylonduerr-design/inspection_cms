class Report < ApplicationRecord
  # --- 1. AUTO-SET DEFAULT VALUES & CALLBACKS ---
  after_initialize :set_defaults, if: :new_record?
  
  # TRIGGER: Run the logic engine before every save
  before_save :calculate_automatic_result

  def set_defaults
    self.status ||= :creating
    self.result ||= :pending
  end

  # --- 2. VALIDATIONS ---
  validates :start_date, presence: true
  validates :project, presence: true
  validates :phase, presence: true

  # --- 3. ASSOCIATIONS ---
  belongs_to :project
  belongs_to :phase
  belongs_to :user
  
  has_many :activity_logs, dependent: :destroy
  
  # ATTACHMENTS
  has_many :report_attachments, dependent: :destroy
  accepts_nested_attributes_for :report_attachments, allow_destroy: true
  has_many_attached :attachments

  # NESTED ENTRIES (The "Big Four" Tables)
  
  # A. INSPECTION ENTRIES (Bid Items)
  has_many :placed_quantities, dependent: :destroy
  accepts_nested_attributes_for :placed_quantities, allow_destroy: true, reject_if: :all_blank

  # B. CHECKLIST ENTRIES (New!)
  has_many :checklist_entries, dependent: :destroy

  # C. EQUIPMENT ENTRIES
  has_many :equipment_entries, dependent: :destroy
  # REJECT IF: Make/Model is blank
  accepts_nested_attributes_for :equipment_entries, 
                                allow_destroy: true, 
                                reject_if: proc { |att| att['make_model'].blank? }

  # D. CREW ENTRIES
  has_many :crew_entries, dependent: :destroy
  # REJECT IF: No key crew fields are entered
  accepts_nested_attributes_for :crew_entries, 
                                allow_destroy: true, 
                                reject_if: proc { |att| att['foreman'].blank? && att['superintendent'].blank? && att['laborer_count'].blank? }

  # E. QA ENTRIES
  has_many :qa_entries, dependent: :destroy
  accepts_nested_attributes_for :qa_entries, allow_destroy: true, reject_if: :all_blank

  # --- 4. ENUMS ---
  enum status: { creating: 0, qc_review: 1, revise: 2, authorization: 3 }
  enum result: { pending: 0, pass: 1, fail: 2, as_built: 3 }
  
  enum deficiency_status: { no_deficiency: 0, yes_deficiency: 1, cdr: 2, ncr: 3 }
  
  enum traffic_control: { tc_na: 0, tc_yes: 1, tc_no: 2 }
  enum environmental: { env_na: 0, env_yes: 1, env_no: 2 }
  enum security: { sec_na: 0, sec_yes: 1, sec_no: 2 }
  enum safety_incident: { safety_no: 0, safety_yes: 1, safety_na: 2 }
  
  enum air_ops_coordination: { air_na: 0, air_yes: 1, air_no: 2 }
  enum swppp_controls: { swppp_na: 0, swppp_yes: 1, swppp_no: 2 }

  # --- 5. SEARCH SCOPES ---
  scope :filter_by_inspector, ->(query) { 
    joins(:user).where("users.email ILIKE ?", "%#{query}%") if query.present?
  }

  scope :filter_by_project, ->(project_id) { where(project_id: project_id) if project_id.present? }
  
  scope :filter_by_bid_item, ->(bid_item_id) {
    joins(:placed_quantities).where(placed_quantities: { bid_item_id: bid_item_id }).distinct if bid_item_id.present?
  }
  
  scope :filter_by_date_range, ->(start_date, end_date) { 
    where(start_date: start_date..end_date) if start_date.present? && end_date.present?
  }

  # --- 6. HELPER METHODS ---
  
  # LOGIC ENGINE: "Worst-to-Best" Result Calculation
  def calculate_automatic_result
    # TIER 1: AUTOMATIC FAIL (The "Worst" Case)
    # Fails if NCR/CDR exists OR if any attached QA entry is 'qa_fail'
    if cdr? || ncr? || qa_entries.any? { |test| test.qa_fail? }
      self.result = :fail
      return
    end

    # TIER 2: PENDING (The "Middle" Case)
    # Pending if minor deficiency exists OR if any QA entry is 'qa_pending'
    if yes_deficiency? || qa_entries.any? { |test| test.qa_pending? }
      self.result = :pending
      return
    end

    # TIER 3: PASS (The "Best" Case)
    # If we survive the checks above, the report passes.
    self.result = :pass
  end

  def inspector_name
    # Update this to user&.full_name if you implemented the Name migration!
    user&.email 
  end
end