class Report < ApplicationRecord
  # --- 1. AUTO-SET DEFAULT VALUES ---
  after_initialize :set_defaults, if: :new_record?

  def set_defaults
    self.status ||= :creating
    self.result ||= :pending
  end

 # --- 2. VALIDATIONS ---
  # UPDATE: Renamed from inspection_date
  validates :start_date, presence: true
  validates :project, presence: true
  validates :phase, presence: true

  # --- 3. ASSOCIATIONS ---
  belongs_to :project
  belongs_to :phase
  belongs_to :user
  has_many :qa_entries, dependent: :destroy
  accepts_nested_attributes_for :qa_entries, allow_destroy: true, reject_if: :all_blank
  
  # NESTED ENTRIES (Quantities & Equipment)
  has_many :inspection_entries, dependent: :destroy
  accepts_nested_attributes_for :inspection_entries, allow_destroy: true, reject_if: :all_blank

  has_many :report_attachments, dependent: :destroy
  accepts_nested_attributes_for :report_attachments, allow_destroy: true

  has_many :equipment_entries, dependent: :destroy
  accepts_nested_attributes_for :equipment_entries, allow_destroy: true, reject_if: :all_blank

  has_many :activity_logs, dependent: :destroy

  # FILE ATTACHMENTS
  has_many_attached :attachments

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
  
  # OPTIMIZATION: We now join the 'users' table and search by email
  scope :filter_by_inspector, ->(query) { 
    joins(:user).where("users.email ILIKE ?", "%#{query}%") if query.present? 
  }

  scope :filter_by_project, ->(project_id) { where(project_id: project_id) if project_id.present? }
  
  scope :filter_by_date_range, ->(start_date, end_date) { 
    where(inspection_date: start_date..end_date) if start_date.present? && end_date.present? 
  }
  
  scope :filter_by_bid_item, ->(bid_item_id) {
    joins(:inspection_entries).where(inspection_entries: { bid_item_id: bid_item_id }).distinct if bid_item_id.present?
  }
  scope :filter_by_date_range, ->(start_date, end_date) { 
    where(start_date: start_date..end_date) if start_date.present? && end_date.present?
  }

  # --- 6. HELPER METHODS ---
  
  # This acts as a bridge. If a view calls @report.inspector_name, 
  # it grabs the email from the associated User.
  def inspector_name
    user&.email
  end
end