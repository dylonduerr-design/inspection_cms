require 'csv'
require 'docx'     # Added
require 'tempfile' # Added

class ReportsController < ApplicationController
  before_action :authenticate_user!
  # Added :export_word to the list of actions that need @report set
  before_action :set_report, only: %i[ show edit update destroy submit_for_qc approve request_revision export_word ]

  # GET /reports
  def index
    # 1. Base Scope (Security)
    @reports = if ['creating', 'revise'].include?(params[:status])
                 current_user.reports
               else
                 Report.all
               end

    # 2. Apply Filters
    apply_search_filters

    # 3. Handle Output
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
    @report = Report.new
    3.times { @report.inspection_entries.build }
    1.times { @report.equipment_entries.build }
  end

  # GET /reports/1/edit
  def edit
    @report.inspection_entries.build if @report.inspection_entries.empty?
    @report.equipment_entries.build if @report.equipment_entries.empty?
  end

  # POST /reports
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
    # 1. Load the template
    template_path = Rails.root.join('app', 'assets', 'documents', 'inspection_template.docx').to_s
    doc = Docx::Document.open(template_path)

    # 2. Define the Mapping for Single Fields
    data_mapping = {
      # Headers
      '{{DIR_NUM}}'   => @report.dir_number,
      '{{DATE}}'      => @report.inspection_date&.strftime("%m/%d/%Y"),
      '{{PROJECT}}'   => @report.project&.name,
      '{{PHASE}}'     => @report.phase&.name,
      '{{INSPECTOR}}' => @report.user&.email,
      
      # Shift / Weather
      '{{SHIFT}}'     => "#{@report.shift_start} - #{@report.shift_end}",
      '{{WEATHER}}'   => @report.weather,
      '{{TEMP}}'      => @report.temperature,
      '{{CONTRACTOR}}'=> @report.contractor,

      # Enums (Using helper method below)
      '{{TC_STATUS}}' => humanize_enum(@report.traffic_control),
      '{{ENV_STATUS}}'=> humanize_enum(@report.environmental),
      '{{SEC_STATUS}}'=> humanize_enum(@report.security),
      '{{SAF_STATUS}}'=> humanize_enum(@report.safety_incident),

      # Narratives
      '{{COMMENTARY}}'=> @report.commentary,
      '{{DEFICIENCY}}'=> @report.deficiency_desc
    }

    # 3. Replace text in General Paragraphs & Tables
    doc.paragraphs.each { |p| replace_tags(p, data_mapping) }
    doc.tables.each do |table|
      table.rows.each do |row|
        row.cells.each do |cell|
          cell.paragraphs.each { |p| replace_tags(p, data_mapping) }
        end
      end
    end

    # 4. Handle DYNAMIC TABLE: Bid Items
    # Find table where header contains "Item Code"
    bid_table = doc.tables.find { |t| t.rows[0].cells.any? { |c| c.text.include?("Item Code") } }
    
    if bid_table && @report.inspection_entries.any?
      template_row = bid_table.rows[1] # Assumes row 1 is the template
      
      @report.inspection_entries.each do |entry|
        new_row = template_row.copy
        
        # Manually target cells (Index 0 = Col 1, Index 1 = Col 2, etc.)
        # Ensure you handle nil values with &. and to_s
        new_row.cells[0].paragraphs[0].text = entry.bid_item&.code.to_s
        new_row.cells[1].paragraphs[0].text = entry.bid_item&.description.to_s
        new_row.cells[2].paragraphs[0].text = entry.quantity.to_s
        new_row.cells[3].paragraphs[0].text = entry.bid_item&.unit.to_s
        new_row.cells[4].paragraphs[0].text = entry.location.to_s
        new_row.cells[5].paragraphs[0].text = entry.notes.to_s
        
        new_row.insert_before(template_row)
      end
      
      template_row.remove # Delete the placeholder row
    end

    # 5. Handle DYNAMIC TABLE: Equipment
    # Find table where header contains "Make/Model"
    equip_table = doc.tables.find { |t| t.rows[0].cells.any? { |c| c.text.include?("Make/Model") } }
    
    if equip_table && @report.equipment_entries.any?
      template_row = equip_table.rows[1]
      
      @report.equipment_entries.each do |entry|
        new_row = template_row.copy
        
        new_row.cells[0].paragraphs[0].text = entry.make_model.to_s
        new_row.cells[1].paragraphs[0].text = entry.hours.to_s
        
        new_row.insert_before(template_row)
      end
      
      template_row.remove
    end

    # 6. Save and Send
    temp_file = Tempfile.new(['inspection', '.docx'])
    
    begin
      doc.save(temp_file.path)
      file_data = File.binread(temp_file.path)
      
      send_data file_data, 
                filename: "DIR_#{@report.dir_number}_#{@report.inspection_date}.docx",
                type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                disposition: 'attachment'
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  private

    def set_report
      @report = Report.find(params[:id])
    end

    # Helper to clean up replacement logic
    def replace_tags(paragraph, mapping)
      mapping.each do |key, value|
        if paragraph.text.include?(key)
          paragraph.text = paragraph.text.gsub(key, value.to_s)
        end
      end
    end

    # Helper to turn "tc_yes" into "Yes"
    def humanize_enum(val)
      case val
      when 'tc_yes', 'env_yes', 'sec_yes', 'safety_yes' then 'Yes'
      when 'tc_no', 'env_no', 'sec_no', 'safety_no'     then 'No'
      when 'tc_na', 'env_na', 'sec_na', 'safety_na'     then 'N/A'
      else val&.humanize
      end
    end

    def apply_search_filters
      @reports = @reports.where(status: params[:status]) if params[:status].present? && params[:status] != 'all'
      @reports = @reports.filter_by_inspector(params[:inspector]) if params[:inspector].present?
      @reports = @reports.filter_by_project(params[:project_id]) if params[:project_id].present?
      @reports = @reports.filter_by_bid_item(params[:bid_item_id]) if params[:bid_item_id].present?
      @reports = @reports.filter_by_date_range(params[:start_date], params[:end_date]) if params[:start_date].present?
      
      if params[:result].present?
        @reports = params[:result] == 'pending' ? @reports.where(result: [nil, '']) : @reports.where(result: params[:result])
      end
    end

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
        attachments: [], 
        inspection_entries_attributes: [:id, :bid_item_id, :quantity, :location, :notes, :_destroy],
        equipment_entries_attributes: [:id, :make_model, :hours, :_destroy],
        report_attachments_attributes: [:id, :caption, :file, :_destroy]
      )
    end

    def generate_csv(reports)
      CSV.generate(headers: true) do |csv|
        csv << [
          "DIR #", "Date", "Inspector", "Project", "Phase", "Status", 
          "Shift", "Weather", "Temp (F)", "Contractor",
          "Item Code", "Item Description", "Quantity", "Unit", "Location", "Notes"
        ]
        
        reports.each do |report|
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