require 'csv'

class ReportsController < ApplicationController
  before_action :authenticate_user! # Ensure user is logged in
  before_action :set_report, only: %i[ show edit update destroy submit_for_qc approve request_revision ]

  # GET /reports
  def index
    # 1. Base Scope (Security)
    # Start with ALL reports, or just your own if strictly necessary. 
    # For now, we follow your logic: 'creating'/'revise' = private, others = public.
    @reports = if ['creating', 'revise'].include?(params[:status])
                 current_user.reports
               else
                 Report.all
               end

    # 2. Apply Filters (Refactored to be cleaner)
    apply_search_filters

    # 3. Handle Output
    respond_to do |format|
      format.html # renders index.html.erb
      format.csv { send_data generate_csv(@reports), filename: "Project_Master_Log_#{Date.today}.csv" }
    end
  end

  # GET /reports/1
  def show
  end

  # GET /reports/new
  def new
    @report = Report.new
    
    # Pre-build some blank rows for the form
    3.times { @report.inspection_entries.build }
    1.times { @report.equipment_entries.build }
  end

  # GET /reports/1/edit
  def edit
    # Only build new lines if none exist
    @report.inspection_entries.build if @report.inspection_entries.empty?
    @report.equipment_entries.build if @report.equipment_entries.empty?
  end

  # POST /reports
  def create
    # We explicitly link the report to the current_user here
    @report = current_user.reports.build(report_params)
    @report.status ||= :creating

    if @report.save
      redirect_to report_url(@report), notice: "Report was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /reports/1
  def update
    if @report.update(report_params)
      redirect_to report_url(@report), notice: "Report was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /reports/1
  def destroy
    @report.destroy!
    redirect_to reports_url, notice: "Report was successfully destroyed."
  end

  # --- Workflow Actions ---

  def submit_for_qc
    @report.update(status: :qc_review)
    redirect_to reports_path, notice: "Report submitted to QC."
  end

  def approve
    @report.update(status: :authorization, result: :pass)
    redirect_to @report, notice: "Report approved and authorized."
  end

  def request_revision
    # CRITICAL FIX: 'user' must be an ID/Object, not a string "QC Manager"
    @report.update(status: :revise, result: :fail)
    @report.activity_logs.create(user: current_user, note: params[:note])
    
    redirect_to @report, alert: "Report returned for revision."
  end

  private

    def set_report
      @report = Report.find(params[:id])
    end

    # --- Refactored Filter Logic ---
    def apply_search_filters
      # Use the scopes we defined in the Report model
      @reports = @reports.where(status: params[:status]) if params[:status].present? && params[:status] != 'all'
      @reports = @reports.filter_by_inspector(params[:inspector]) if params[:inspector].present?
      @reports = @reports.filter_by_project(params[:project_id]) if params[:project_id].present?
      @reports = @reports.filter_by_bid_item(params[:bid_item_id]) if params[:bid_item_id].present?
      @reports = @reports.filter_by_date_range(params[:start_date], params[:end_date]) if params[:start_date].present?
      
      # Handle 'pending' result explicitly
      if params[:result].present?
        @reports = params[:result] == 'pending' ? @reports.where(result: [nil, '']) : @reports.where(result: params[:result])
      end
    end

    # --- Strong Parameters ---
    def report_params
      params.require(:report).permit(
        :dir_number, :inspection_date, :project_id, :phase_id, 
        :status, :result,
        :shift_start, :shift_end, :weather, :temperature,
        :station_start, :station_end, :contractor, :plan_sheet, :relevant_docs,
        :deficiency_status, :deficiency_desc,
        :traffic_control, :environmental, :security, :safety_incident, :safety_desc,
        :commentary,
        :qa_activity, :qa_bid_item_id, :qa_type, :qa_result,
        :foreman, :laborer_count, :operator_count, :survey_count,
        # Removed :inspector (deleted column)
        # Removed :report_attachments_attributes (deleted table)
        attachments: [], # Native ActiveStorage
        inspection_entries_attributes: [:id, :bid_item_id, :quantity, :location, :notes, :_destroy],
        equipment_entries_attributes: [:id, :make_model, :hours, :_destroy],
        report_attachments_attributes: [:id, :caption, :file, :_destroy]
      )
    end

    # --- CSV Generation (Private helper) ---
    def generate_csv(reports)
      CSV.generate(headers: true) do |csv|
        csv << [
          "DIR #", "Date", "Inspector", "Project", "Phase", "Status", 
          "Shift", "Weather", "Temp (F)", "Contractor",
          "Item Code", "Item Description", "Quantity", "Unit", "Location", "Notes"
        ]
        
        reports.each do |report|
          # Use report.user.email since report.inspector is gone
          inspector_name = report.user&.email || "Unknown"

          if report.inspection_entries.empty?
            csv << [
              report.dir_number, report.inspection_date, inspector_name, report.project&.name, report.phase&.name, report.status&.humanize,
              "#{report.shift_start}-#{report.shift_end}", report.weather, report.temperature, report.contractor,
              "---", "No Activity", 0, "---", "---", report.commentary
            ]
          else
            report.inspection_entries.each do |entry|
              csv << [
                report.dir_number, report.inspection_date, inspector_name, report.project&.name, report.phase&.name, report.status&.humanize,
                "#{report.shift_start}-#{report.shift_end}", report.weather, report.temperature, report.contractor,
                entry.bid_item&.code, entry.bid_item&.description, entry.quantity, entry.bid_item&.unit, entry.location, entry.notes
              ]
            end
          end
        end
      end
    end
end