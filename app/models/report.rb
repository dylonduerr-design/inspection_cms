class Report < ApplicationRecord
  after_initialize :set_defaults, if: :new_record?
  before_save :calculate_automatic_result

  belongs_to :project, optional: true
  belongs_to :phase, optional: true
  belongs_to :user
  
  has_many :activity_logs, dependent: :destroy

  
  has_many :placed_quantities, dependent: :destroy
  accepts_nested_attributes_for :placed_quantities, 
                                allow_destroy: true, 
                                reject_if: proc { |att| att['bid_item_id'].blank? }

  has_many :equipment_entries, dependent: :destroy
  accepts_nested_attributes_for :equipment_entries, 
                                allow_destroy: true, 
                                reject_if: proc { |att| att['make_model'].blank? && att['contractor'].blank? && att['quantity'].blank? && att['hours'].blank? }

  has_many :crew_entries, dependent: :destroy
  accepts_nested_attributes_for :crew_entries, 
                                allow_destroy: true, 
                                reject_if: proc { |att| att['contractor'].blank? }

  has_many :qa_entries, dependent: :destroy
  accepts_nested_attributes_for :qa_entries, allow_destroy: true, reject_if: :all_blank

  has_many :report_attachments, dependent: :destroy
  accepts_nested_attributes_for :report_attachments, allow_destroy: true

  has_many :checklist_entries, dependent: :destroy
  accepts_nested_attributes_for :checklist_entries, 
                                allow_destroy: true, 
                                reject_if: :all_blank

  validates :start_date, presence: true
  validates :project, presence: true
  
  validates :phase, presence: true

  
  enum status: { creating: 0, qc_review: 1, revise: 2, authorization: 3 }
  enum result: { pending: 0, pass: 1, fail: 2, as_built: 3 }
  
  enum deficiency_status: { no_deficiency: 0, yes_deficiency: 1, cdr: 2, ncr: 3 }
  enum safety_incident:   { safety_no: 0, safety_yes: 1, safety_na: 2 }
  
  enum traffic_control:       { tc_na: 0, tc_yes: 1, tc_no: 2 }
  enum environmental:         { env_na: 0, env_yes: 1, env_no: 2 }
  enum security:              { sec_na: 0, sec_yes: 1, sec_no: 2 }
  enum air_ops_coordination:  { air_na: 0, air_yes: 1, air_no: 2 }
  enum swppp_controls:        { swppp_na: 0, swppp_yes: 1, swppp_no: 2 }
  enum phasing_compliance:    { phase_na: 0, phase_yes: 1, phase_no: 2 }

  scope :filter_by_inspector, ->(query) { 
    joins(:user).where("users.email ILIKE ?", "%#{query}%") 
  }
  
  scope :filter_by_project, ->(project_id) { where(project_id: project_id) }
  
  scope :filter_by_bid_item, ->(bid_item_id) {
    joins(:placed_quantities).where(placed_quantities: { bid_item_id: bid_item_id }).distinct
  }

  scope :filter_by_date_range, ->(start_date, end_date) { 
    where(start_date: start_date..end_date) 
  }

  scope :filter_by_precip_range, ->(min, max) {
    safe_cast = ->(col) { "CASE WHEN #{col} ~ '^[0-9]+(\\.[0-9]+)?$' THEN #{col}::numeric ELSE 0 END" }
    where(
      "(#{safe_cast.call('precip_1')} BETWEEN ? AND ?) OR " \
      "(#{safe_cast.call('precip_2')} BETWEEN ? AND ?) OR " \
      "(#{safe_cast.call('precip_3')} BETWEEN ? AND ?)",
      min, max, min, max, min, max
    )
  }

  
  def set_defaults
    self.status ||= :creating
    self.result ||= :pending
    
    self.start_date ||= Date.current
    self.shift_start ||= Time.current.strftime("%H:%M")
    
    self.deficiency_status ||= :no_deficiency
    self.safety_incident ||= :safety_na
    self.traffic_control ||= :tc_na
    self.environmental ||= :env_na
    self.security ||= :sec_na
    self.air_ops_coordination ||= :air_na
    self.swppp_controls ||= :swppp_na
    self.phasing_compliance ||= :phase_na
  end

  def calculate_automatic_result
    if cdr? || ncr? || qa_entries.any?(&:qa_fail?)
      self.result = :fail
      return
    end

    if yes_deficiency? || qa_entries.any?(&:qa_pending?)
      self.result = :pending
      return
    end

    self.result = :pass
  end

  def inspector_name
    user&.email
  end
  
  def contract_day_display
    return nil unless project&.contract_start_date && project&.contract_days && start_date
    
    days_since_start = (start_date - project.contract_start_date).to_i + 1
    total_days = project.contract_days
    
    "Contract Day #{days_since_start} of #{total_days}"
  end
end
