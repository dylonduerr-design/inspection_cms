class PlacedQuantitiesController < ApplicationController
  before_action :set_placed_quantity, only: %i[ show edit update destroy ]

  # GET /placed_quantities or /placed_quantities.json
  def index
    @placed_quantities = PlacedQuantity.all
  end

  # GET /placed_quantities/1 or /placed_quantities/1.json
  def show
  end

  # GET /placed_quantities/new
  def new
    @placed_quantity = PlacedQuantity.new
  end

  # GET /placed_quantities/1/edit
  def edit
  end

  # POST /placed_quantities or /placed_quantities.json
  def create
    @placed_quantity = PlacedQuantity.new(placed_quantity_params)

    respond_to do |format|
      if @placed_quantity.save
        format.html { redirect_to @placed_quantity, notice: "Inspection entry was successfully created." }
        format.json { render :show, status: :created, location: @placed_quantity }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @placed_quantity.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /placed_quantities/1 or /placed_quantities/1.json
  def update
    respond_to do |format|
      if @placed_quantity.update(placed_quantity_params)
        format.html { redirect_to @placed_quantity, notice: "Inspection entry was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @placed_quantity }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @placed_quantity.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /placed_quantities/1 or /placed_quantities/1.json
  def destroy
    @placed_quantity.destroy!
    respond_to do |format|
      format.html { redirect_to placed_quantities_path, notice: "Inspection entry was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_placed_quantity
      @placed_quantity = PlacedQuantity.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def placed_quantity_params
      params.require(:placed_quantity).permit(:report_id, :bid_item_id, :quantity, :location, :notes)
    end
end