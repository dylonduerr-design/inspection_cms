class BidItemsController < ApplicationController
  before_action :set_bid_item, only: %i[ show edit update destroy ]

  # GET /bid_items
  def index
    # The Dashboard Logic: Sums quantities per item
    @bid_items = BidItem.left_joins(:inspection_entries)
                        .group(:id)
                        .select("bid_items.*, COALESCE(SUM(inspection_entries.quantity), 0) as total_quantity")
                        .order(:code)
  end

  # GET /bid_items/1
  def show
  end

  # GET /bid_items/new
  def new
    @bid_item = BidItem.new
  end

  # GET /bid_items/1/edit
  def edit
  end

  # POST /bid_items
  def create
    @bid_item = BidItem.new(bid_item_params)

    if @bid_item.save
      redirect_to bid_item_url(@bid_item), notice: "Bid item was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /bid_items/1
  def update
    if @bid_item.update(bid_item_params)
      redirect_to bid_item_url(@bid_item), notice: "Bid item was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /bid_items/1
  def destroy
    @bid_item.destroy!

    redirect_to bid_items_url, notice: "Bid item was successfully destroyed."
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_bid_item
      @bid_item = BidItem.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
   def bid_item_params
  # We permit :questions_text INSTEAD of :checklist_questions
  params.require(:bid_item).permit(:code, :description, :unit, :questions_text)
 end
end
