class Report < ApplicationRecord
  # --- 1. AUTO-SET DEFAULT VALUES ---
  after_initialize :set_defaults, if: :new_record?

  def set_defaults
    self.status ||= :creating
    self.result ||= :pending
  end

  # --- 2. VALIDATIONS (The Safety Net) ---
  # These lines prevent "ghost" reports by blocking saves missing key info
  validates :inspection_date, presence: true
  validates :inspector, presence: true
  validates :project, presence: true
  validates :phase, presence: true

  # Optional: specific format validations if needed
  # validates :dir_number, uniqueness: true, allow_blank: true

  # --- 3. ASSOCIATIONS ---
  belongs_to :project
  belongs_to :phase
  belongs_to :user
  
  
  # NESTED ENTRIES (Quantities & Equipment)
  has_many :inspection_entries, dependent: :destroy
  accepts_nested_attributes_for :inspection_entries, allow_destroy: true, reject_if: :all_blank

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
  
  enum qa_type: { density: 0, gradation: 1, smoothness: 2, final_grade: 3, compaction: 4, surface_prep: 5 }
  enum qa_result: { qa_pass: 0, qa_fail: 1, results_pending: 2, info_only: 3 }

  # --- 5. SEARCH SCOPES ---
  scope :filter_by_inspector, ->(name) { where("inspector ILIKE ?", "%#{name}%") if name.present? }
  scope :filter_by_project, ->(project_id) { where(project_id: project_id) if project_id.present? }
  scope :filter_by_date_range, ->(start_date, end_date) { 
    where(inspection_date: start_date..end_date) if start_date.present? && end_date.present? 
  }
  scope :filter_by_bid_item, ->(bid_item_id) {
    joins(:inspection_entries).where(inspection_entries: { bid_item_id: bid_item_id }).distinct if bid_item_id.present?
  }
end