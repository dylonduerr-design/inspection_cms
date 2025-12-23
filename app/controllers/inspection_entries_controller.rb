class InspectionEntriesController < ApplicationController
  before_action :set_inspection_entry, only: %i[ show edit update destroy ]

  # GET /inspection_entries or /inspection_entries.json
  def index
    @inspection_entries = InspectionEntry.all
  end

  # GET /inspection_entries/1 or /inspection_entries/1.json
  def show
  end

  # GET /inspection_entries/new
  def new
    @inspection_entry = InspectionEntry.new
  end

  # GET /inspection_entries/1/edit
  def edit
  end

  # POST /inspection_entries or /inspection_entries.json
  def create
    @inspection_entry = InspectionEntry.new(inspection_entry_params)

    respond_to do |format|
      if @inspection_entry.save
        format.html { redirect_to @inspection_entry, notice: "Inspection entry was successfully created." }
        format.json { render :show, status: :created, location: @inspection_entry }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @inspection_entry.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /inspection_entries/1 or /inspection_entries/1.json
  def update
    respond_to do |format|
      if @inspection_entry.update(inspection_entry_params)
        format.html { redirect_to @inspection_entry, notice: "Inspection entry was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @inspection_entry }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @inspection_entry.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /inspection_entries/1 or /inspection_entries/1.json
  def destroy
    @inspection_entry.destroy!

    respond_to do |format|
      format.html { redirect_to inspection_entries_path, notice: "Inspection entry was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_inspection_entry
      @inspection_entry = InspectionEntry.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def inspection_entry_params
      params.require(:inspection_entry).permit(:report_id, :bid_item_id, :quantity, :location, :notes)
    end
end
