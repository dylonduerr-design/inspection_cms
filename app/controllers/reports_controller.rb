require 'csv'

class ReportsController < ApplicationController
  before_action :set_report, only: %i[ show edit update destroy submit_for_qc approve request_revision ]

  # GET /reports
  def index
    # 1. Default to 'creating' if no status is provided
    if params[:status].blank?
      params[:status] = 'creating'
    end

    # 2. Start the query
    @reports = Report.all

    # 3. Apply the Status filter (UNLESS the user specifically asked for 'all')
    if params[:status] != 'all'
      @reports = @reports.where(status: params[:status])
    end

    # 4. Apply other filters
    if params[:inspector].present?
      @reports = @reports.where("inspector ILIKE ?", "%#{params[:inspector]}%")
    end
    
    if params[:project_id].present?
      @reports = @reports.where(project_id: params[:project_id])
    end

    if params[:bid_item_id].present?
      @reports = @reports.joins(:inspection_entries).where(inspection_entries: { bid_item_id: params[:bid_item_id] })
    end
    
    if params[:start_date].present?
      @reports = @reports.where("inspection_date >= ?", params[:start_date])
    end
    
    if params[:end_date].present?
      @reports = @reports.where("inspection_date <= ?", params[:end_date])
    end

    # 5. Handle the Export
    respond_to do |format|
      format.html # Renders the normal web page
      
      format.csv do
        response.headers['Content-Type'] = 'text/csv'
        response.headers['Content-Disposition'] = "attachment; filename=Project_Master_Log_#{Date.today}.csv"
        
        # Generator for the CSV
        csv_data = CSV.generate(headers: true) do |csv|
          # A. The Header Row
          csv << [
            "DIR #", "Date", "Inspector", "Project", "Phase", "Status", 
            "Shift", "Weather", "Temp (F)", "Contractor",
            "Item Code", "Item Description", "Quantity", "Unit", "Location", "Notes"
          ]
          
          # B. The Data Rows
          @reports.each do |report|
            if report.inspection_entries.empty?
              csv << [
                report.dir_number, report.inspection_date, report.inspector, report.project&.name, report.phase&.name, report.status&.humanize,
                "#{report.shift_start}-#{report.shift_end}", report.weather, report.temperature, report.contractor,
                "---", "No Activity", 0, "---", "---", report.commentary
              ]
            else
              report.inspection_entries.each do |entry|
                csv << [
                  report.dir_number, report.inspection_date, report.inspector, report.project&.name, report.phase&.name, report.status&.humanize,
                  "#{report.shift_start}-#{report.shift_end}", report.weather, report.temperature, report.contractor,
                  entry.bid_item&.code, entry.bid_item&.description, entry.quantity, entry.bid_item&.unit, entry.location, entry.notes
                ]
              end
            end
          end
        end
        
        render plain: csv_data
      end
    end
  end # <--- THIS IS THE CORRECT END FOR THE INDEX METHOD

  # GET /reports/1
  def show
  end

  # GET /reports/new
  def new
    @report = Report.new
    3.times { @report.inspection_entries.build }
    1.times { @report.equipment_entries.build }
  end

  # GET /reports/1/edit
  def edit
    @report.inspection_entries.build
    @report.equipment_entries.build
  end

  # POST /reports
  def create
    @report = Report.new(report_params)

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
    redirect_to @report, notice: "Report submitted to QC."
  end

  def approve
    @report.update(status: :authorization, result: :pass)
    redirect_to @report, notice: "Report approved and authorized."
  end

  def request_revision
    @report.update(status: :revise, result: :fail)
    @report.activity_logs.create(user: "QC Manager", note: params[:note])
    redirect_to @report, alert: "Report returned for revision."
  end

  private
    def set_report
      @report = Report.find(params[:id])
    end

    def report_params
      params.require(:report).permit(
        :dir_number, :inspection_date, :inspector, :project_id, :phase_id, 
        :status, :result,
        :shift_start, :shift_end, :weather, :temperature,
        :station_start, :station_end, :contractor, :plan_sheet, :relevant_docs,
        :deficiency_status, :deficiency_desc,
        :traffic_control, :environmental, :security, :safety_incident, :safety_desc,
        :commentary,
        :qa_activity, :qa_bid_item_id, :qa_type, :qa_result,
        :foreman, :laborer_count, :operator_count, :survey_count,
        attachments: [], 
        inspection_entries_attributes: [:id, :bid_item_id, :quantity, :location, :notes, :_destroy],
        equipment_entries_attributes: [:id, :make_model, :hours, :_destroy]
      )
    end
end
