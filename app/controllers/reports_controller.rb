require 'csv'
require 'docx'
require 'tempfile'

class ReportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_report, only: %i[ show edit update destroy submit_for_qc approve request_revision export_word ]

  # GET /reports
  def index
    # 1. DEFAULT: Set the default status to match your View's default tab
    params[:status] ||= 'creating'

    # 2. SCOPE: Determine base collection (Security/Workflow logic)
    # Inspectors should only see their own reports in 'creating' or 'revise' stages.
    # For all other stages (QC, Authorization), we show the global list.
    @reports = if ['creating', 'revise'].include?(params[:status])
                 current_user.reports 
               else
                 Report.all
               end

    # 3. FILTER: Actually apply the status filter
    @reports = @reports.where(status: params[:status]) unless params[:status] == 'all'

    # 4. SEARCH: Apply the remaining filters (Date, Project, Inspector)
    apply_search_filters

    respond_to do |format|
      format.html
      format.csv { send_data generate_csv(@reports), filename: "Project_Master_Log_#{Date.today}.csv" }
    end
  end

  # GET /reports/1
  def show
  end

  # GET /reports/new
  def new
    # --- MAESTRO: DRAFT PATTERN IMPLEMENTATION ---
    # 1. Initialize with defaults
    @report = current_user.reports.build(status: :creating)
    
    # 2. Pre-fill Project if passed from Dashboard
    if params[:project_id].present?
      project = Project.find_by(id: params[:project_id])
      @report.project = project if project
    end

    # 3. Save Shell Record (validate: false)
    if @report.save(validate: false)
      redirect_to edit_report_path(@report)
    else
      redirect_to reports_path, alert: "Could not initialize new report."
    end
  end

  # GET /reports/1/edit
  def edit
    @report.placed_quantities.build if @report.placed_quantities.empty?
    @report.equipment_entries.build if @report.equipment_entries.empty?
  end

  # POST /reports
  # Note: With Draft Pattern, this action is rarely hit (since 'new' redirects to 'edit' -> 'update'),
  # but we keep it for fallback or API usage.
  def create
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
    @report.update(status: :revise, result: :fail)
    @report.activity_logs.create(user: current_user, note: params[:note])
    redirect_to @report, alert: "Report returned for revision."
  end

  # --- EXPORT TO WORD ACTION ---
  def export_word
    # 1. Delegate the work to your Service Class
    temp_file = WordReportExporter.generate(@report)

    if temp_file
      begin
        # 2. Read the binary data from the temp file path
        file_data = File.binread(temp_file.path)
        
        # 3. Send the data to the browser
        send_data file_data, 
                  filename: "DIR_#{@report.dir_number}_#{@report.start_date}.docx",
                  type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                  disposition: 'attachment'
      ensure
        # 4. Clean up the temp file
        temp_file.close
        temp_file.unlink
      end
    else
      # Fallback if the template is missing
      redirect_to @report, alert: "Could not generate report. Template missing."
    end
  end

  private

    def set_report
      @report = Report.find(params[:id])
    end

    def apply_search_filters
      # NOTE: Status filtering is now handled in the index action!

      @reports = @reports.filter_by_inspector(params[:inspector]) if params[:inspector].present?
      @reports = @reports.filter_by_project(params[:project_id]) if params[:project_id].present?
      @reports = @reports.filter_by_bid_item(params[:bid_item_id]) if params[:bid_item_id].present?

      # Updated Precip Filter
      # We assume the user wants to find records with "At least X amount of rain"
      if params[:precip_min].present?
         max = params[:precip_max].presence || 100 # Default max if user leaves it blank
         @reports = @reports.filter_by_precip_range(params[:precip_min], max)
      end

      # Date Range Filter
      if params[:start_date].present?
        # Ensure we handle the end date if the scope expects a range
        end_date = params[:end_date].presence || params[:start_date]
        @reports = @reports.filter_by_date_range(params[:start_date], end_date) 
      end

      if params[:result].present?
        @reports = params[:result] == 'pending' ? @reports.where(result: [nil, '']) : @reports.where(result: params[:result])
      end
    end

    def generate_csv(reports)
      CSV.generate(headers: true) do |csv|
        csv << [
          "DIR #", "Start Date", "End Date", "Inspector", "Project", "Phase", "Status", 
          "Shift", "Temps (1/2/3)", "Winds (1/2/3)", "Contractor",
          "Item Code", "Item Description", "Quantity", "Unit", "Location", "Notes"
        ]
        
        reports.each do |report|
          inspector_name = report.user&.email || "Unknown"
          
          # Combine weather for CSV readability
          temps = [report.temp_1, report.temp_2, report.temp_3].compact.join("/")
          winds = [report.wind_1, report.wind_2, report.wind_3].compact.join("/")

          if report.placed_quantities.empty?
            csv << [
              report.dir_number, report.start_date, report.end_date, inspector_name, report.project&.name, report.phase&.name, report.status&.humanize,
              "#{report.shift_start}-#{report.shift_end}", temps, winds, report.contractor,
              "---", "No Activity", 0, "---", "---", report.commentary
            ]
          else
            report.placed_quantities.each do |entry|
              csv << [
                report.dir_number, report.start_date, report.end_date, inspector_name, report.project&.name, report.phase&.name, report.status&.humanize,
                "#{report.shift_start}-#{report.shift_end}", temps, winds, report.contractor,
                entry.bid_item&.code, entry.bid_item&.description, entry.quantity, entry.bid_item&.unit, entry.location, entry.notes
              ]
            end
          end
        end
      end
    end

    def report_params
      params.require(:report).permit(
        # --- 1. GENERAL INFO ---
        :start_date, :end_date,
        :dir_number, :project_id, :phase_id, 
        :status, :result,
        :shift_start, :shift_end,
        :contractor, 

        # --- 2. WEATHER & CONDITIONS ---
        :temp_1, :temp_2, :temp_3,
        :wind_1, :wind_2, :wind_3,
        :precip_1, :precip_2, :precip_3,
        :weather_summary_1, :weather_summary_2, :weather_summary_3,
        :weather, :temperature,
        :station_start, :station_end, :plan_sheet, :relevant_docs,
        
        # --- 3. COMPLIANCE & SAFETY ---
        :deficiency_status, :deficiency_desc,
        :traffic_control, :environmental, :security, :safety_incident, 
        :air_ops_coordination, :swppp_controls,
        :safety_desc, :commentary,

        # --- 4. TEXT AREAS ---
        :additional_activities, :additional_info,
        
        # --- 5. ATTACHMENTS ---
        report_attachments_attributes: [:id, :caption, :file, :_destroy],

        # --- 6. NESTED TABLES ---
        crew_entries_attributes: [
          :id, :contractor, :superintendent, :foreman, 
          :survey_count, :operator_count, :laborer_count, :electrician_count, 
          :notes, :_destroy
        ],
        equipment_entries_attributes: [
          :id, :make_model, :hours, :quantity, :contractor, :_destroy
        ],
        placed_quantities_attributes: [
          :id, :bid_item_id, :quantity, :notes, :_destroy, 
          :checklist_answers 
        ],
        # MAESTRO: Added to support nested checklists if needed in future
        checklist_entries_attributes: [:id, :spec_item_id, :_destroy, checklist_answers: {}],

        qa_entries_attributes: [
          :id, :qa_type, :location, :result, :note, :_destroy
        ]
      )
    end
end