class Report < ApplicationRecord
  # --- 1. AUTO-SET DEFAULT VALUES & CALLBACKS ---
  after_initialize :set_defaults, if: :new_record?
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
  belongs_to :project, optional: true
  belongs_to :phase, optional: true
  belongs_to :user
  
  has_many :activity_logs, dependent: :destroy
  
  # ATTACHMENTS
  has_many :report_attachments, dependent: :destroy
  accepts_nested_attributes_for :report_attachments, allow_destroy: true

  # NESTED ENTRIES
  has_many :placed_quantities, dependent: :destroy
  accepts_nested_attributes_for :placed_quantities, allow_destroy: true, reject_if: :all_blank

  has_many :checklist_entries, dependent: :destroy

  has_many :equipment_entries, dependent: :destroy
  accepts_nested_attributes_for :equipment_entries, allow_destroy: true, reject_if: proc { |att| att['make_model'].blank? }

  has_many :crew_entries, dependent: :destroy
  accepts_nested_attributes_for :crew_entries, allow_destroy: true, reject_if: proc { |att| att['foreman'].blank? && att['superintendent'].blank? && att['laborer_count'].blank? }

  has_many :qa_entries, dependent: :destroy
  accepts_nested_attributes_for :qa_entries, allow_destroy: true, reject_if: :all_blank

  # --- 4. ENUMS ---
  enum status: { creating: 0, qc_review: 1, revise: 2, authorization: 3 }
  enum result: { pending: 0, pass: 1, fail: 2, as_built: 3 }
  enum deficiency_status: { no_deficiency: 0, yes_deficiency: 1, cdr: 2, ncr: 3 }
  
  # Site Conditions
  enum traffic_control: { tc_na: 0, tc_yes: 1, tc_no: 2 }
  enum environmental: { env_na: 0, env_yes: 1, env_no: 2 }
  enum security: { sec_na: 0, sec_yes: 1, sec_no: 2 }
  enum safety_incident: { safety_no: 0, safety_yes: 1, safety_na: 2 }
  enum air_ops_coordination: { air_na: 0, air_yes: 1, air_no: 2 }
  enum swppp_controls: { swppp_na: 0, swppp_yes: 1, swppp_no: 2 }

  # --- 5. SEARCH SCOPES (Expanded) ---
  
  # Existing Scopes
  scope :filter_by_inspector, ->(query) { 
    joins(:user).where("users.email ILIKE ?", "%#{query}%") if query.present?
  }
  scope :filter_by_project, ->(project_id) { where(project_id: project_id) if project_id.present? }
  scope :filter_by_date_range, ->(start_date, end_date) { 
    where(start_date: start_date..end_date) if start_date.present? && end_date.present?
  }
  
  # Bid Item Filter (Kept for compatibility)
  scope :filter_by_bid_item, ->(bid_item_id) {
    joins(:placed_quantities).where(placed_quantities: { bid_item_id: bid_item_id }).distinct if bid_item_id.present?
  }

  # --- NEW MAESTRO FILTERS ---

  # 1. Filter by QA Test Type (e.g., "Find all reports with Concrete Slump tests")
  scope :filter_by_test_type, ->(qa_type_val) {
    return unless qa_type_val.present?
    # We join qa_entries and filter by the integer enum value
    joins(:qa_entries).where(qa_entries: { qa_type: qa_type_val }).distinct
  }

  # 2. Filter by Spec Item (Deep Nested Search)
  # Finds reports that have a Bid Item linked to a specific Spec (e.g., "P-401")
  scope :filter_by_spec_item, ->(spec_item_id) {
    return unless spec_item_id.present?
    joins(placed_quantities: { bid_item: :spec_item })
      .where(spec_items: { id: spec_item_id })
      .distinct
  }

  # 3. Filter by Precipitation (Smart Numeric Cast)
  # USAGE: Report.filter_by_precip_range(0.1, 5.0)
  # LOGIC: "Treat 'Trace' or 'None' as 0. Treat '0.50' as 0.5. Find matches in range."
  scope :filter_by_precip_range, ->(min, max) {
    return unless min.present? && max.present?
    
    # Helper to build the safe conversion SQL for a column
    # If the column matches a number regex, cast it. Otherwise, treat as 0.
    safe_cast = ->(col) { 
      "CASE WHEN #{col} ~ '^[0-9]+(\\.[0-9]+)?$' THEN #{col}::numeric ELSE 0 END" 
    }

    where(
      "(#{safe_cast.call('precip_1')} BETWEEN ? AND ?) OR " \
      "(#{safe_cast.call('precip_2')} BETWEEN ? AND ?) OR " \
      "(#{safe_cast.call('precip_3')} BETWEEN ? AND ?)",
      min, max, min, max, min, max
    )
  }
  # --- 6. HELPER METHODS ---
  def calculate_automatic_result
    if cdr? || ncr? || qa_entries.any? { |test| test.qa_fail? }
      self.result = :fail
      return
    end

    if yes_deficiency? || qa_entries.any? { |test| test.qa_pending? }
      self.result = :pending
      return
    end

    self.result = :pass
  end

  def inspector_name
    user&.email
  end
end