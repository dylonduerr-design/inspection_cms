require 'csv'
require 'docx'
require 'tempfile'

class ReportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_report, only: %i[ show edit update destroy submit_for_qc approve request_revision export_word ]

  # GET /reports
  def index
    # 1. DEFAULT: Set the default status
    params[:status] ||= 'creating'

    # 2. SCOPE: Determine base collection
    # Inspectors see their own in 'creating/revise', global view for others.
    @reports = if ['creating', 'revise'].include?(params[:status])
                 current_user.reports 
               else
                 Report.all
               end

    # 3. FILTER: Apply status filter
    @reports = @reports.where(status: params[:status]) unless params[:status] == 'all'

    # 4. SEARCH: Apply remaining filters
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
    # 1. Initialize empty shell
    @report = current_user.reports.build(status: :creating)
    
    # 2. Pre-fill Project Data
    if params[:project_id].present?
      @project = Project.find_by(id: params[:project_id])
      
      if @project
        @report.project = @project
        
        # Auto-fill header info
        @report.contractor = @project.respond_to?(:prime_contractor) ? @project.prime_contractor : nil
        
        # MAESTRO FIX: Removed assignment to deleted 'superintendent' column
      end
    end

    # 3. Build Nested Shells (So the form shows empty rows to fill in)
    @report.placed_quantities.build
    @report.equipment_entries.build
    @report.crew_entries.build
    
    # Note: We do NOT build checklist_entries here anymore.
    # 4. Render the 'new' view directly (DO NOT SAVE/REDIRECT)
  end

  # GET /reports/1/edit
  def edit
    # MAESTRO: Ensure form has empty rows if current data is empty
    @report.placed_quantities.build if @report.placed_quantities.empty?
    @report.equipment_entries.build if @report.equipment_entries.empty?
    @report.crew_entries.build if @report.crew_entries.empty?
  end

  # POST /reports
  def create
    # This is where the record is actually saved for the first time.
    # The params will include the Report attributes AND the nested checklist answers.
    @report = current_user.reports.build(report_params)
    @report.status = :creating # Enforce status

    if @report.save
      redirect_to report_url(@report), notice: "Report was successfully created."
    else
      # If validation fails, we must re-set the @project for the view to render
      @project = @report.project 
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
    redirect_to reports_url, notice: "Report was successfully deleted."
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
    temp_file = WordReportExporter.generate(@report)

    if temp_file
      begin
        file_data = File.binread(temp_file.path)
        send_data file_data, 
                  filename: "DIR_#{@report.dir_number}_#{@report.start_date}.docx",
                  type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                  disposition: 'attachment'
      ensure
        temp_file.close
        temp_file.unlink
      end
    else
      redirect_to @report, alert: "Could not generate report. Template missing."
    end
  end

  private

    def set_report
      @report = Report.find(params[:id])
    end

    def apply_search_filters
      @reports = @reports.filter_by_inspector(params[:inspector]) if params[:inspector].present?
      @reports = @reports.filter_by_project(params[:project_id]) if params[:project_id].present?
      @reports = @reports.filter_by_bid_item(params[:bid_item_id]) if params[:bid_item_id].present?

      if params[:precip_min].present?
         max = params[:precip_max].presence || 100 
         @reports = @reports.filter_by_precip_range(params[:precip_min], max)
      end

      if params[:start_date].present?
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
        :prime_contractor, # MAESTRO: :superintendent removed here

        # --- 2. WEATHER & CONDITIONS ---
        :temp_1, :temp_2, :temp_3,
        :wind_1, :wind_2, :wind_3,
        :precip_1, :precip_2, :precip_3,
        :weather_summary_1, :weather_summary_2, :weather_summary_3,
        :weather, :temperature,
        :visibility_1, :visibility_2, :visibility_3,
        :surface_conditions,

        :station_start, :station_end, :plan_sheet, :relevant_docs,
        
        # --- 3. COMPLIANCE & SAFETY ---
        :deficiency_status, :deficiency_desc,
        :safety_incident, :safety_desc,
        :commentary,
        :traffic_control, :traffic_control_note,
        :environmental, :environmental_note,
        :security, :security_note,
        :air_ops_coordination, :air_ops_note,
        :swppp_controls, :swppp_note,
        :phasing_compliance, :phasing_compliance_note,

        # --- 4. TEXT AREAS ---
        :additional_activities, :additional_info,
        
        # --- 5. ATTACHMENTS ---
        report_attachments_attributes: [:id, :caption, :file, :_destroy],

        # --- 6. NESTED TABLES ---
        crew_entries_attributes: [
          :id, :contractor,
          :superintendent_count, :foreman_count, # MAESTRO: Updated to counts
          :survey_count, :operator_count, :laborer_count, :electrician_count, 
          :notes, :_destroy
        ],
        equipment_entries_attributes: [
          :id, :make_model, :hours, :quantity, :contractor, :_destroy
        ],
        placed_quantities_attributes: [
          :id, :bid_item_id, :quantity, :notes, :location, :_destroy, 
          :checklist_answers 
        ],
        
        # MAESTRO: This allows flexible JSON/Hash storage for answers
        checklist_entries_attributes: [:id, :spec_item_id, :_destroy, checklist_answers: {}],

        qa_entries_attributes: [
          # MAESTRO: Changed :note to :remarks to match your DB schema and View
          :id, :qa_type, :location, :result, :remarks, :_destroy
        ]
      )
    end
end