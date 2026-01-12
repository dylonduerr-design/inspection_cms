require 'docx'
require 'tempfile'

class WordReportExporter
  def self.generate(report)
    # 1. LOAD TEMPLATE (prefer the Context dummy, fall back to legacy location)
    template_candidates = [
      Rails.root.join('app', 'assets', 'Context', 'inspection_template.docx'),
      Rails.root.join('app', 'assets', 'documents', 'inspection_template.docx')
    ]
    template_path = template_candidates.find { |path| File.exist?(path) }
    return nil unless template_path

    # 2. PREPARE CAPTION MAPPING
    # Maps attachment captions to placeholders {{CAPTION 1}} ... {{CAPTION 6}}
    caption_map = {}
    (1..6).each do |i|
      attachment = report.report_attachments[i-1]
      text = attachment ? (attachment.caption || "") : ""
      caption_map["{{CAPTION #{i}}}"] = text
    end

    # 3. DEFINE REPLACEMENTS
    # These are simple text replacements for the header/footer/body
    base_replacements = {
      # --- General Info ---
      '{{PROJECT}}'            => report.project&.name,
      '{{PROJECT MANAGER}}'    => report.project&.project_manager,
      '{{CONSTRUCTION_MANAGER}}' => report.project&.construction_manager,
      '{{CONTRACTOR}}'         => report.contractor.presence || report.project&.prime_contractor,
      '{{DATE}}'               => format_date(report.start_date),
      '{{START_DATE}}'         => format_date(report.start_date),
      '{{END_DATE}}'           => format_date(report.end_date),
      '{{DAY_X_OF_Y}}'         => report.contract_day_display,
      '{{START_SHIFT}}'        => report.shift_start,
      '{{END_SHIFT}}'          => report.shift_end,
      '{{INSPECTOR}}'          => report.inspector_name,

      # --- Weather ---
      '{{TEMP}}'          => slash_join(report.temp_1, report.temp_2, report.temp_3),
      '{{WEATHER}}'       => slash_join(report.weather_summary_1, report.weather_summary_2, report.weather_summary_3),
      '{{WEATHER_EVENT}}' => slash_join(report.weather_summary_1, report.weather_summary_2, report.weather_summary_3),
      '{{WIND}}'          => slash_join(report.wind_1, report.wind_2, report.wind_3),
      '{{PRECIP}}'        => slash_join(report.precip_1, report.precip_2, report.precip_3),
      '{{VIS}}'           => slash_join(report.visibility_1, report.visibility_2, report.visibility_3, fallback: "N/A"),
      '{{SURFACE}}'       => report.surface_conditions.presence || "N/A",

      # --- Compliance & Safety ---
      '{{SEC_STATUS}}'      => human_enum(report.security),
      '{{TC_STATUS}}'       => human_enum(report.traffic_control),
      '{{AIR_OPS}}'         => human_enum(report.air_ops_coordination),
      '{{SWPPP}}'           => human_enum(report.swppp_controls),
      '{{ENV_STATUS}}'      => human_enum(report.environmental),
      '{{PHASE_STATUS}}'    => human_enum(report.phasing_compliance),
      '{{SAF_STATUS}}'      => human_enum(report.safety_incident),
      '{{SAF_DESCRIPTION}}' => report.safety_desc || "None",
      '{{DEF_STATUS}}'      => human_enum(report.deficiency_status),
      '{{DEF_DESC}}'        => report.deficiency_desc || "None",

      # --- Commentary ---
      '{{COMMENTARY}}'   => report.commentary,
      '{{ADD_ACTIVITY}}' => report.additional_activities,
      '{{ADD_INFO}}'     => report.additional_info
    }

    replacements = base_replacements.merge(caption_map)

    # 4. OPEN DOCUMENT
    doc = Docx::Document.open(template_path.to_s)

    # 5. GLOBAL FIND & REPLACE
    replace_all(doc, replacements)

    # 6. DYNAMIC TABLE PROCESSING
    # We scan tables for specific placeholder rows and duplicate them for each data entry.
    doc.tables.each do |table|
      
      # A. QA TABLE
      if table_has_placeholder?(table, '[TEST]')
        populate_table(table, report.qa_entries, {
          '[CODE]'     => :qa_type,
          '[TEST]'     => :qa_type,
          '[LOCATION]' => :location,
          '[RESULT]'   => :result,
          '[REMARKS]'  => :remarks
        })
      end

      # B. PLACED QUANTITIES (BID ITEMS) TABLE
      # Note: This logic matches the new PlacedQuantities naming
      if table_has_placeholder?(table, '[DESC]')
        populate_table(table, report.placed_quantities, {
          '[CODE]'  => ->(entry) { entry.bid_item&.code },
          '[DESC]'  => ->(entry) { entry.bid_item&.description },
          '[QTY]'   => :quantity,
          '[NOTES]' => :notes
        })
      end

      # C. WORKFORCE TABLE (Nested Crew Entries)
      if table_has_placeholder?(table, '[CONTRACTOR]')
        populate_table(table, report.crew_entries, {
          '[CONTRACTOR]'  => :contractor,
          '[SURVEY]'      => :survey_count,
          '[SUPER]'       => :superintendent,
          '[FOREMAN]'     => :foreman,
          '[OPERATOR]'    => :operator_count,
          '[LABORER]'     => :laborer_count,
          '[ELECTRICIAN]' => :electrician_count
        })
      end

      # D. EQUIPMENT TABLE
      if table_has_placeholder?(table, '[EQUIPMENT]')
        populate_table(table, report.equipment_entries, {
          '[EQUIPMENT]' => :make_model,
          '[QTY]'       => :quantity,
          '[HOURS]'     => :hours
        })
      end
    end

    # 7. SAVE TO TEMP FILE
    temp_file = Tempfile.new(['report', '.docx'])
    doc.save(temp_file.path)
    temp_file
  end

  private

  # Helper: Converts enum strings like "qa_pass" to "Pass" or "traffic_yes" to "Yes"
  def self.human_enum(val)
    return "N/A" if val.nil?

    str = val.to_s
    return "N/A" if str == "0" || str.end_with?('_na')

    # Splits "safety_yes" -> "Yes", "qa_fail" -> "Fail"
    str.include?('_') ? str.split('_').last.capitalize : str.humanize
  end

  def self.format_date(date)
    date&.strftime("%m/%d/%Y")
  end

  def self.slash_join(*values, fallback: "")
    joined = values.compact.reject(&:blank?).join(' / ')
    joined.presence || fallback.to_s
  end

  # Helper: Iterates through document paragraphs to replace text
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

  def self.clean_text(text)
    text.gsub(/[“”]/, '"')
  end

  # --- CORE TABLE POPULATION LOGIC ---
  # Finds a row with placeholders, duplicates it for each data item, fills it, and deletes the template row.
  def self.populate_table(table, data_collection, mapping)
    # 1. Find the template row index
    template_row_index = table.rows.find_index do |row|
      row.cells.any? { |cell| mapping.keys.any? { |k| clean_text(cell.text).include?(k) } }
    end
    return unless template_row_index

    template_row = table.rows[template_row_index]

    data_collection.each do |item|
      # 2. Deep Clone
      new_row = template_row.copy
      
      # 3. Insert BEFORE the template row
      template_row.node.add_previous_sibling(new_row.node)

      # 4. Fill Data
      new_row.cells.each do |cell|
        mapping.each do |placeholder, attribute|
          if clean_text(cell.text).include?(placeholder)
            # Resolve the value
            val = if attribute.is_a?(Proc)
                    attribute.call(item)
                  elsif item.respond_to?(attribute)
                    val_raw = item.send(attribute)
                    # Check if it's an enum needing formatting
                    val_raw.is_a?(String) && item.class.defined_enums.has_key?(attribute.to_s) ? human_enum(val_raw) : val_raw
                  else
                    ""
                  end

            # Replace text safely inside paragraphs
            regex = /["“”]?#{Regexp.escape(placeholder)}["“”]?/
            cell.paragraphs.each do |p|
              p.text = p.text.gsub(regex, val.to_s)
            end
          end
        end
      end
    end

    # 5. Remove the template row
    template_row.node.remove
  end
end