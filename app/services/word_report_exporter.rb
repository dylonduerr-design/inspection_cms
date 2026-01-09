require 'docx'

class WordReportExporter
  def self.generate(report)
    # 1. LOAD TEMPLATE
    template_path = Rails.root.join('app', 'assets', 'documents', 'inspection_template.docx')
    return nil unless File.exist?(template_path)

    # 2. PREPARE CAPTION MAPPING
    caption_map = {}
    (1..6).each do |i|
      attachment = report.report_attachments[i-1]
      text = attachment ? (attachment.caption || "") : ""
      caption_map["{{CAPTION #{i}}}"] = text
    end

    # 3. DEFINE REPLACEMENTS
    base_replacements = {
      # --- General Info ---
      '{{PROJECT}}' => report.project&.name,
      '{{START_DATE}}' => report.start_date&.strftime("%m/%d/%Y"),
      '{{START_SHIFT}}' => report.shift_start,
      '{{END_DATE}}' => report.end_date&.strftime("%m/%d/%Y"),
      '{{END_SHIFT}}' => report.shift_end,
      '{{INSPECTOR}}' => report.user.respond_to?(:full_name) ? report.user.full_name : report.user.email,

      # --- Weather ---
      '{{TEMP}}' => [report.temp_1, report.temp_2, report.temp_3].compact.join(' / '),
      '{{WEATHER}}' => [report.weather_summary_1, report.weather_summary_2, report.weather_summary_3].compact.join(' / '),
      '{{WIND}}' => [report.wind_1, report.wind_2, report.wind_3].compact.join(' / '),
      '{{PRECIP}}' => [report.precip_1, report.precip_2, report.precip_3].compact.join(' / '),
      '{{VIS}}' => "N/A",
      '{{SURFACE}}' => "N/A",
      '{{WEATHER_EVENT}}' => "N/A",

      # --- Compliance ---
      '{{SEC_STATUS}}' => human_enum(report.security),
      '{{TC_STATUS}}' => human_enum(report.traffic_control),
      '{{AIR_OPS}}' => human_enum(report.air_ops_coordination),
      '{{SWPPP}}' => human_enum(report.swppp_controls),
      '{{ENV_STATUS}}' => human_enum(report.environmental),
      '{{SAF_STATUS}}' => human_enum(report.safety_incident),
      '{{SAF_DESCRIPTION}}' => report.safety_desc || "None",
      '{{DEF_STATUS}}' => human_enum(report.deficiency_status),
      '{{DEF_DESC}}' => report.deficiency_desc || "None",

      # --- Commentary ---
      '{{COMMENTARY}}' => report.commentary,
      '{{ADD_ACTIVITY}}' => report.additional_activities,
      '{{ADD_INFO}}' => report.additional_info
    }

    replacements = base_replacements.merge(caption_map)

    # 4. OPEN DOCUMENT
    doc = Docx::Document.open(template_path.to_s)

    # 5. GLOBAL FIND & REPLACE
    replace_all(doc, replacements)

    # 6. DYNAMIC TABLE PROCESSING
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
        populate_table(table, report.placed_quantities, {
          '[CODE]' => ->(entry) { entry.bid_item&.code },
          '[DESC]' => ->(entry) { entry.bid_item&.description },
          '[QTY]'  => :quantity,
          '[NOTES]' => :notes
        })
      end

      # C. WORKFORCE TABLE
      if table_has_placeholder?(table, '[CONTRACTOR]')
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

    # 7. SAVE
    temp_file = Tempfile.new(['report', '.docx'])
    doc.save(temp_file.path)
    temp_file
  end

  private

  def self.human_enum(val)
    return "N/A" if val.nil? || val == 0
    val.include?('_') ? val.split('_').last.capitalize : val.humanize
  end

  def self.replace_all(doc, replacements)
    doc.paragraphs.each { |p| replace_in_paragraph(p, replacements) }
    doc.tables.each { |t| replace_in_table(t, replacements) }
  end

  def self.replace_in_paragraph(p, replacements)
    replacements.each { |key, value| p.text = p.text.gsub(key, value.to_s) }
  end

  def self.replace_in_table(table, replacements)
    table.rows.each do |row|
      row.cells.each do |cell|
        cell.paragraphs.each { |p| replace_in_paragraph(p, replacements) }
      end
    end
  end

  def self.table_has_placeholder?(table, tag)
    table.rows.any? { |row| row.cells.any? { |cell| clean_text(cell.text).include?(tag) } }
  end

  # --- HELPER: Table Population (CORRECTED) ---
  def self.populate_table(table, data_collection, mapping)
    # 1. Find the template row
    template_row_index = table.rows.find_index do |row|
      row.cells.any? { |cell| mapping.keys.any? { |k| clean_text(cell.text).include?(k) } }
    end
    return unless template_row_index

    template_row = table.rows[template_row_index]

    data_collection.each do |item|
      # 2. Clone the template row using deeper XML copy
      new_row = template_row.copy
      
      # 3. Insert BEFORE the template row
      template_row.node.add_previous_sibling(new_row.node)

      # 4. Fill in the data
      new_row.cells.each do |cell|
        mapping.each do |placeholder, attribute|
          if clean_text(cell.text).include?(placeholder)
            val = if attribute.is_a?(Proc)
                    attribute.call(item)
                  elsif item.respond_to?(attribute)
                    val_raw = item.send(attribute)
                    val_raw.is_a?(String) && item.class.defined_enums.has_key?(attribute.to_s) ? human_enum(val_raw) : val_raw
                  else
                    ""
                  end

            regex = /["“”]?#{Regexp.escape(placeholder)}["“”]?/
            
            # --- FIX IS HERE ---
            # Instead of cell.text =, we iterate over the paragraphs inside the cell
            cell.paragraphs.each do |p|
              p.text = p.text.gsub(regex, val.to_s)
            end
            # -------------------
          end
        end
      end
    end

    # 5. Remove the template row
    template_row.node.remove
  end

  def self.clean_text(text)
    text.gsub(/[“”]/, '"')
  end
end