class ChecklistEntriesController < ApplicationController
  skip_before_action :verify_authenticity_token # (Optional: purely for ease of JS fetch, better to use headers if possible)

  def create
    @report = Report.find(params[:report_id])
    @spec = SpecItem.find(params[:spec_item_id])
    
    # Find existing entry or start a new one
    @entry = @report.checklist_entries.find_or_initialize_by(spec_item: @spec)
    
    # Save the answers (passed as a JSON object)
    @entry.checklist_answers = params[:answers].permit!.to_h
    
    if @entry.save
      render json: { 
        status: "success", 
        id: @entry.id,
        spec_code: @spec.code,
        spec_desc: @spec.description
      }
    else
      render json: { status: "error", message: @entry.errors.full_messages.join(", ") }, status: 422
    end
  end
end