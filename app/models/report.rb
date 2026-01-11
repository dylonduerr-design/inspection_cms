class Report < ApplicationRecord
  # --- 1. CONFIGURATION & CALLBACKS ---
  after_initialize :set_defaults, if: :new_record?
  before_save :calculate_automatic_result

  # --- 2. ASSOCIATIONS ---
  belongs_to :project, optional: true
  belongs_to :phase, optional: true
  belongs_to :user
  
  has_many :activity_logs, dependent: :destroy

  # --- NESTED ENTRIES (The Big Four) ---
  
  # 1. PLACED QUANTITIES (BID ITEMS)
  # MAESTRO CHANGE: We now reject this row if 'bid_item_id' is missing. 
  # This prevents crashes if the user leaves the default row blank.
  has_many :placed_quantities, dependent: :destroy
  accepts_nested_attributes_for :placed_quantities, 
                                allow_destroy: true, 
                                reject_if: proc { |att| att['bid_item_id'].blank? }

  # 2. EQUIPMENT
  # Rejects if no description (make_model) is provided.
  has_many :equipment_entries, dependent: :destroy
  accepts_nested_attributes_for :equipment_entries, 
                                allow_destroy: true, 
                                reject_if: proc { |att| att['make_model'].blank? }

  # 3. CREW
  # MAESTRO CHANGE: Rejects if 'contractor' is blank. 
  # This allows the auto-spawned crew row to be ignored if unused.
  has_many :crew_entries, dependent: :destroy
  accepts_nested_attributes_for :crew_entries, 
                                allow_destroy: true, 
                                reject_if: proc { |att| att['contractor'].blank? }

  # 4. QA ENTRIES
  has_many :qa_entries, dependent: :destroy
  accepts_nested_attributes_for :qa_entries, allow_destroy: true, reject_if: :all_blank

  # ATTACHMENTS (Wrapper Model)
  has_many :report_attachments, dependent: :destroy
  accepts_nested_attributes_for :report_attachments, allow_destroy: true

  # CHECKLISTS
  has_many :checklist_entries, dependent: :destroy

  # --- 3. VALIDATIONS ---
  # Note: created with 'validate: false' in draft mode, but these run on update/submit.
  validates :start_date, presence: true
  validates :project, presence: true
  validates :phase, presence: true

  # --- 4. ENUMS (Organized by Category) ---
  enum status: { creating: 0, qc_review: 1, revise: 2, authorization: 3 }
  enum result: { pending: 0, pass: 1, fail: 2, as_built: 3 }
  
  # Compliance & Safety
  enum deficiency_status: { no_deficiency: 0, yes_deficiency: 1, cdr: 2, ncr: 3 }
  enum safety_incident:   { safety_no: 0, safety_yes: 1, safety_na: 2 }
  
  # Site Conditions
  enum traffic_control:       { tc_na: 0, tc_yes: 1, tc_no: 2 }
  enum environmental:         { env_na: 0, env_yes: 1, env_no: 2 }
  enum security:              { sec_na: 0, sec_yes: 1, sec_no: 2 }
  enum air_ops_coordination:  { air_na: 0, air_yes: 1, air_no: 2 }
  enum swppp_controls:        { swppp_na: 0, swppp_yes: 1, swppp_no: 2 }

  # --- 5. SEARCH SCOPES ---
  scope :filter_by_inspector, ->(query) { 
    joins(:user).where("users.email ILIKE ?", "%#{query}%") 
  }
  
  scope :filter_by_project, ->(project_id) { where(project_id: project_id) }
  
  scope :filter_by_date_range, ->(start_date, end_date) { 
    where(start_date: start_date..end_date) 
  }

  # Smart Precip Filter (Casts strings like '0.50' to numbers for comparison)
  scope :filter_by_precip_range, ->(min, max) {
    safe_cast = ->(col) { "CASE WHEN #{col} ~ '^[0-9]+(\\.[0-9]+)?$' THEN #{col}::numeric ELSE 0 END" }
    where(
      "(#{safe_cast.call('precip_1')} BETWEEN ? AND ?) OR " \
      "(#{safe_cast.call('precip_2')} BETWEEN ? AND ?) OR " \
      "(#{safe_cast.call('precip_3')} BETWEEN ? AND ?)",
      min, max, min, max, min, max
    )
  }

  # --- 6. LOGIC & HELPERS ---
  
  def set_defaults
    self.status ||= :creating
    self.result ||= :pending
  end

  def calculate_automatic_result
    # Fail if Critical Issues found
    if cdr? || ncr? || qa_entries.any?(&:qa_fail?)
      self.result = :fail
      return
    end

    # Pending if deficiencies exist or QA is incomplete
    if yes_deficiency? || qa_entries.any?(&:qa_pending?)
      self.result = :pending
      return
    end

    self.result = :pass
  end

  def inspector_name
    user&.email
  end
end