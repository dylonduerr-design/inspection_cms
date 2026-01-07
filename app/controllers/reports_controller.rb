require 'csv'
require 'docx'
require 'tempfile'

class ReportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_report, only: %i[ show edit update destroy submit_for_qc approve request_revision export_word ]

  # GET /reports
  def index
    @reports = if ['creating', 'revise'].include?(params[:status])
                 current_user.reports
               else
                 Report.all
               end

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
    @report = Report.new
    # Build 3 entries by default
    3.times { @report.inspection_entries.build }
    # Build 1 equipment entry by default
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
    # Helper for safe strings
    safe_date = @report.start_date&.strftime("%m/%d/%Y")
    
    # Logic to combine the weather trios for old templates
    combined_temp = [@report.temp_1, @report.temp_2, @report.temp_3].compact.join(" / ")
    combined_wind = [@report.wind_1, @report.wind_2, @report.wind_3].compact.join(" / ")
    combined_precip = [@report.precip_1, @report.precip_2, @report.precip_3].compact.join(" / ")

    data_mapping = {
      '{{DIR_NUM}}'    => @report.dir_number,
      '{{DATE}}'       => safe_date,
      '{{END_DATE}}'   => @report.end_date&.strftime("%m/%d/%Y"),
      '{{PROJECT}}'    => @report.project&.name,
      '{{PHASE}}'      => @report.phase&.name,
      '{{INSPECTOR}}'  => @report.user&.email,
      '{{SHIFT}}'      => "#{@report.shift_start} - #{@report.shift_end}",
      
      # Weather Trio Mappings
      '{{TEMP}}'       => combined_temp,      # Combined for backward compatibility
      '{{TEMP_1}}'     => @report.temp_1,
      '{{TEMP_2}}'     => @report.temp_2,
      '{{TEMP_3}}'     => @report.temp_3,

      '{{WIND}}'       => combined_wind,
      '{{WIND_1}}'     => @report.wind_1,
      '{{WIND_2}}'     => @report.wind_2,
      '{{WIND_3}}'     => @report.wind_3,

      '{{PRECIP}}'     => combined_precip,
      '{{PRECIP_1}}'   => @report.precip_1,
      '{{PRECIP_2}}'   => @report.precip_2,
      '{{PRECIP_3}}'   => @report.precip_3,
      
      '{{CONTRACTOR}}' => @report.contractor,
      
      # Enums
      '{{TC_STATUS}}'  => humanize_enum(@report.traffic_control),
      '{{ENV_STATUS}}' => humanize_enum(@report.environmental),
      '{{SEC_STATUS}}' => humanize_enum(@report.security),
      '{{SAF_STATUS}}' => humanize_enum(@report.safety_incident),
      '{{AIR_OPS}}'    => humanize_enum(@report.air_ops_coordination),
      '{{SWPPP}}'      => humanize_enum(@report.swppp_controls),
      
      # Text Blocks
      '{{COMMENTARY}}'   => @report.commentary,
      '{{DEFICIENCY}}'   => @report.deficiency_desc,
      '{{ADD_ACTIVITY}}' => @report.additional_activities,
      '{{ADD_INFO}}'     => @report.additional_info
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
    bid_table = nil
    bid_header_row_index = nil

    # Deep Search for the table
    doc.tables.each do |t|
      t.rows.each_with_index do |row, index|
        if row.cells.any? { |c| c.text.include?("Item Code") }
          bid_table = t
          bid_header_row_index = index
          break
        end
      end
      break if bid_table
    end
    
    if bid_table && bid_header_row_index && @report.inspection_entries.any?
      template_row = bid_table.rows[bid_header_row_index + 1]
      
      @report.inspection_entries.each do |entry|
        new_row = template_row.copy
        
        # MAPPING
        new_row.cells[0].paragraphs[0].text = entry.bid_item&.code.to_s
        new_row.cells[1].paragraphs[0].text = entry.bid_item&.description.to_s
        new_row.cells[2].paragraphs[0].text = entry.quantity.to_s
        new_row.cells[3].paragraphs[0].text = entry.notes.to_s
        
        # Note: If you want to print the checklist answers into the Word Doc, 
        # we would need to loop through entry.checklist_answers here.
        # For now, we leave it as standard columns.
        
        new_row.insert_before(template_row)
      end
      
      template_row.node.remove
    end

    # 5. Handle DYNAMIC TABLE: Equipment
    equip_table = nil
    equip_header_row_index = nil

    # Deep Search for the table
    doc.tables.each do |t|
      t.rows.each_with_index do |row, index|
        if row.cells.any? { |c| c.text.include?("Make/Model") }
          equip_table = t
          equip_header_row_index = index
          break
        end
      end
      break if equip_table
    end
    
    if equip_table && equip_header_row_index && @report.equipment_entries.any?
      template_row = equip_table.rows[equip_header_row_index + 1]
      
      @report.equipment_entries.each do |entry|
        new_row = template_row.copy
        
        new_row.cells[0].paragraphs[0].text = entry.make_model.to_s
        new_row.cells[2].paragraphs[0].text = entry.hours.to_s 
        
        new_row.insert_before(template_row)
      end
      
      template_row.node.remove
    end

    # 6. Save and Send
    temp_file = Tempfile.new(['inspection', '.docx'])
    
    begin
      doc.save(temp_file.path)
      file_data = File.binread(temp_file.path)
      
      send_data file_data, 
                filename: "DIR_#{@report.dir_number}_#{@report.start_date}.docx",
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

    def replace_tags(paragraph, mapping)
      mapping.each do |key, value|
        if paragraph.text.include?(key)
          # Use gsub to replace all instances
          paragraph.text = paragraph.text.gsub(key, value.to_s)
        end
      end
    end

    def humanize_enum(val)
      case val
      # Standard Yes/No/NA logic
      when 'tc_yes', 'env_yes', 'sec_yes', 'safety_yes', 'air_yes', 'swppp_yes' then 'Yes'
      when 'tc_no', 'env_no', 'sec_no', 'safety_no', 'air_no', 'swppp_no'    then 'No'
      when 'tc_na', 'env_na', 'sec_na', 'safety_na', 'air_na', 'swppp_na'    then 'N/A'
      else val&.humanize
      end
    end

    def apply_search_filters
      @reports = @reports.where(status: params[:status]) if params[:status].present? && params[:status] != 'all'
      @reports = @reports.filter_by_inspector(params[:inspector]) if params[:inspector].present?
      @reports = @reports.filter_by_project(params[:project_id]) if params[:project_id].present?
      @reports = @reports.filter_by_bid_item(params[:bid_item_id]) if params[:bid_item_id].present?
      
      # UPDATED: Use start_date
      @reports = @reports.filter_by_date_range(params[:start_date], params[:end_date]) if params[:start_date].present?
      
      if params[:result].present?
        @reports = params[:result] == 'pending' ? @reports.where(result: [nil, '']) : @reports.where(result: params[:result])
      end
    end

    def report_params
      params.require(:report).permit(
        # --- 1. NEW DATE FIELDS ---
        :start_date, 
        :end_date,
        
        :dir_number, :project_id, :phase_id, 
        :status, :result,
        :shift_start, :shift_end,
        
        # --- 2. WEATHER TRIO & OLD FIELDS ---
        :temp_1, :temp_2, :temp_3,
        :wind_1, :wind_2, :wind_3,
        :precip_1, :precip_2, :precip_3,
        :weather, :temperature,
        
        :station_start, :station_end, :contractor, :plan_sheet, :relevant_docs,
        :deficiency_status, :deficiency_desc,
        
        # --- 3. NEW & OLD ENUMS ---
        :traffic_control, :environmental, :security, :safety_incident, 
        :air_ops_coordination, :swppp_controls,
        
        :safety_desc, :commentary,
        
        # --- 4. NEW TEXT FIELDS ---
        :additional_activities, :additional_info,

        :qa_activity, :qa_bid_item_id, :qa_type, :qa_result,
        :foreman, :laborer_count, :operator_count, :survey_count,
        
        attachments: [], 
        
        # --- 5. NESTED ATTRIBUTES w/ JSONB ---
        # Note the { checklist_answers: {} } at the end!
        inspection_entries_attributes: [
          :id, :bid_item_id, :quantity, :location, :notes, :_destroy,
          { checklist_answers: {} } 
        ],
        
        equipment_entries_attributes: [:id, :make_model, :hours, :_destroy],
        report_attachments_attributes: [:id, :caption, :file, :_destroy]
      )
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

          if report.inspection_entries.empty?
            csv << [
              report.dir_number, report.start_date, report.end_date, inspector_name, report.project&.name, report.phase&.name, report.status&.humanize,
              "#{report.shift_start}-#{report.shift_end}", temps, winds, report.contractor,
              "---", "No Activity", 0, "---", "---", report.commentary
            ]
          else
            report.inspection_entries.each do |entry|
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
end