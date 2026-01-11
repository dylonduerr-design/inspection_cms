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
  has_many :placed_quantities, dependent: :destroy
  accepts_nested_attributes_for :placed_quantities, 
                                allow_destroy: true, 
                                reject_if: proc { |att| att['bid_item_id'].blank? }

  # 2. EQUIPMENT
  has_many :equipment_entries, dependent: :destroy
  accepts_nested_attributes_for :equipment_entries, 
                                allow_destroy: true, 
                                reject_if: proc { |att| att['make_model'].blank? }

  # 3. CREW
  has_many :crew_entries, dependent: :destroy
  accepts_nested_attributes_for :crew_entries, 
                                allow_destroy: true, 
                                reject_if: proc { |att| att['contractor'].blank? }

  # 4. QA ENTRIES
  has_many :qa_entries, dependent: :destroy
  accepts_nested_attributes_for :qa_entries, allow_destroy: true, reject_if: :all_blank

  # 5. ATTACHMENTS
  has_many :report_attachments, dependent: :destroy
  accepts_nested_attributes_for :report_attachments, allow_destroy: true

  # 6. CHECKLISTS (CRITICAL UPDATE)
  # This enables the "Save Parent = Save Children" behavior for specs
  has_many :checklist_entries, dependent: :destroy
  accepts_nested_attributes_for :checklist_entries, 
                                allow_destroy: true, 
                                reject_if: :all_blank

  # --- 3. VALIDATIONS ---
  validates :start_date, presence: true
  validates :project, presence: true
  
  # Note: You might want to make Phase optional if it's not known immediately, 
  # but strictly speaking, a report should belong to a phase.
  validates :phase, presence: true

  # --- 4. ENUMS ---
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
  enum phasing_compliance:    { phase_na: 0, phase_yes: 1, phase_no: 2 }

  # --- 5. SEARCH SCOPES ---
  scope :filter_by_inspector, ->(query) { 
    joins(:user).where("users.email ILIKE ?", "%#{query}%") 
  }
  
  scope :filter_by_project, ->(project_id) { where(project_id: project_id) }
  
  # Filters reports that contain a specific bid item in their quantities
  scope :filter_by_bid_item, ->(bid_item_id) {
    joins(:placed_quantities).where(placed_quantities: { bid_item_id: bid_item_id }).distinct
  }

  scope :filter_by_date_range, ->(start_date, end_date) { 
    where(start_date: start_date..end_date) 
  }

  # Smart Precip Filter (Handles text inputs by casting safe numbers)
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
    # 1. Immediate Fail triggers
    if cdr? || ncr? || qa_entries.any?(&:qa_fail?)
      self.result = :fail
      return
    end

    # 2. Pending triggers (Issues found but not critical, or testing incomplete)
    if yes_deficiency? || qa_entries.any?(&:qa_pending?)
      self.result = :pending
      return
    end

    # 3. Default Pass
    self.result = :pass
  end

  def inspector_name
    user&.email
  end
end