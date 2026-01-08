require 'docx'

class WordReportExporter
  def self.generate(report)
    # 1. LOAD TEMPLATE
    # Make sure this matches your actual file location
    template_path = Rails.root.join('app', 'assets', 'documents', 'inspection_template.docx')
    return nil unless File.exist?(template_path)

    doc = Docx::Document.open(template_path)

    # 2. DEFINE REPLACEMENTS
    replacements = {
      # --- General Info ---
      '{{PROJECT}}' => report.project&.name,
      '{{START_DATE}}' => report.start_date&.strftime("%m/%d/%Y"),
      '{{START_SHIFT}}' => report.shift_start,
      '{{END_DATE}}' => report.end_date&.strftime("%m/%d/%Y"),
      '{{END_SHIFT}}' => report.shift_end,
      '{{INSPECTOR}}' => report.user.respond_to?(:full_name) ? report.user.full_name : report.user.email,
      
      # --- Weather (Combined) ---
      '{{TEMP}}' => [report.temp_1, report.temp_2, report.temp_3].compact.join(' / '),
      '{{WEATHER}}' => [report.weather_summary_1, report.weather_summary_2, report.weather_summary_3].compact.join(' / '),
      '{{WIND}}' => [report.wind_1, report.wind_2, report.wind_3].compact.join(' / '),
      '{{PRECIP}}' => [report.precip_1, report.precip_2, report.precip_3].compact.join(' / '),
      '{{VIS}}' => "N/A",           # Placeholder until you add this column
      '{{SURFACE}}' => "N/A",       # Placeholder until you add this column
      '{{WEATHER_EVENT}}' => "N/A", # Placeholder until you add this column

      # --- Compliance & Safety ---
      '{{SEC_STATUS}}' => report.security&.humanize,
      '{{TC_STATUS}}' => report.traffic_control&.humanize,
      '{{AIR_OPS}}' => report.air_ops_coordination&.humanize,
      '{{SWPPP}}' => report.swppp_controls&.humanize,
      '{{ENV_STATUS}}' => report.environmental&.humanize,
      '{{SAF_STATUS}}' => report.safety_incident&.humanize,
      '{{SAF_DESCRIPTION}}' => report.safety_desc || "None",

      # --- Deficiencies ---
      '{{DEF_STATUS}}' => report.deficiency_status&.humanize, 
      '{{DEF_DESC}}' => report.deficiency_desc || "None",
      
      # --- Commentary ---
      '{{COMMENTARY}}' => report.commentary,
      '{{ADD_ACTIVITY}}' => report.additional_activities,
      '{{ADD_INFO}}' => report.additional_info
    }

    # 3. GLOBAL FIND & REPLACE (The Fix)
    # This searches regular paragraphs AND table cells
    replace_all(doc, replacements)

    # 4. DYNAMIC TABLE PROCESSING
    doc.tables.each do |table|
      
      # A. QA TABLE
      if table_has_placeholder?(table, '[TEST]')
        populate_table(table, report.qa_entries, {
          '[CODE]' => :qa_type, 
          '[TEST]' => :qa_type,
          '[LOCATION]' => :location,
          '[RESULT]' => :result,
          '[REMARKS]' => :remarks
        })
      end

      # B. BID ITEMS TABLE
      if table_has_placeholder?(table, '[DESC]')
        populate_table(table, report.inspection_entries, {
          '[CODE]' => ->(entry) { entry.bid_item&.code },
          '[DESC]' => ->(entry) { entry.bid_item&.description },
          '[QTY]'  => :quantity,
          '[NOTES]' => :notes
        })
      end

      # C. WORKFORCE TABLE
      if table_has_placeholder?(table, '[CONTRACTOR]') # Note capitalization check
        populate_table(table, report.crew_entries, {
          '[CONTRACTOR]' => :contractor,
          '[SURVEY]' => :survey_count,
          '[SUPER]' => :superintendent,
          '[FOREMAN]' => :foreman,
          '[OPERATOR]' => :operator_count,
          '[LABORER]' => :laborer_count,
          '[ELECTRICIAN]' => :electrician_count
        })
      end

      # D. EQUIPMENT TABLE
      if table_has_placeholder?(table, '[EQUIPMENT]')
        populate_table(table, report.equipment_entries, {
          '[EQUIPMENT]' => :make_model,
          '[QTY]' => :quantity,
          '[HOURS]' => :hours
        })
      end
    end

    # 5. SAVE
    temp_file = Tempfile.new(['report', '.docx'])
    doc.save(temp_file.path)
    temp_file
  end

  private

  # --- HELPER 1: Global Replacement ---
  def self.replace_all(doc, replacements)
    # 1. Scan Main Body Paragraphs
    doc.paragraphs.each do |p|
      replacements.each { |key, value| p.text = p.text.gsub(key, value.to_s) }
    end

    # 2. Scan ALL Tables (This fixes your Header/General Info bugs)
    doc.tables.each do |table|
      table.rows.each do |row|
        row.cells.each do |cell|
          cell.paragraphs.each do |p|
            replacements.each { |key, value| p.text = p.text.gsub(key, value.to_s) }
          end
        end
      end
    end
  end

  # --- HELPER 2: Table Detection (Smart Quote Proof) ---
  def self.table_has_placeholder?(table, tag)
    # We clean the text (remove quotes) to ensure we find [TAG] even if Word made it “[TAG]”
    table.rows.any? { |row| row.cells.any? { |cell| clean_text(cell.text).include?(tag) } }
  end

  # --- HELPER 3: Table Population ---
  def self.populate_table(table, data_collection, mapping)
    # Find the row, ignoring quote styles
    template_row_index = table.rows.find_index do |row| 
      row.cells.any? { |cell| mapping.keys.any? { |k| clean_text(cell.text).include?(k) } } 
    end
    return unless template_row_index

    template_row = table.rows[template_row_index]

    data_collection.each do |item|
      new_row = table.send(:insert_row_after, table.rows.size - 1, template_row)
      
      new_row.cells.each do |cell|
        mapping.each do |placeholder, attribute|
          # Check for placeholder (ignoring quotes)
          if clean_text(cell.text).include?(placeholder)
            
            val = if attribute.is_a?(Proc)
                    attribute.call(item)
                  elsif item.respond_to?(attribute)
                    val_raw = item.send(attribute)
                    val_raw.is_a?(String) && item.class.defined_enums.has_key?(attribute.to_s) ? val_raw.humanize.titleize : val_raw
                  else
                    ""
                  end
            
            # Replace the placeholder (handling the dirty quotes in the doc)
            # We use a regex to match [TAG] with or without surrounding quotes
            regex = /["“”]?#{Regexp.escape(placeholder)}["“”]?/
            cell.text = cell.text.gsub(regex, val.to_s)
          end
        end
      end
    end

    table.remove_row(template_row_index)
  end

  # Utility to strip smart quotes for comparison
  def self.clean_text(text)
    text.gsub(/[“”]/, '"')
  end
end