require "test_helper"

class InspectionEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @placed_quantity = placed_quantities(:one)
  end

  test "should get index" do
    get placed_quantities_url
    assert_response :success
  end

  test "should get new" do
    get new_placed_quantity_url
    assert_response :success
  end

  test "should create placed_quantity" do
    assert_difference("PlacedQuantity.count") do
      post placed_quantities_url, params: { placed_quantity: { bid_item_id: @placed_quantity.bid_item_id, location: @placed_quantity.location, notes: @placed_quantity.notes, quantity: @placed_quantity.quantity, report_id: @placed_quantity.report_id } }
    end

    assert_redirected_to placed_quantity_url(PlacedQuantity.last)
  end

  test "should show placed_quantity" do
    get placed_quantity_url(@placed_quantity)
    assert_response :success
  end

  test "should get edit" do
    get edit_placed_quantity_url(@placed_quantity)
    assert_response :success
  end

  test "should update placed_quantity" do
    patch placed_quantity_url(@placed_quantity), params: { placed_quantity: { bid_item_id: @placed_quantity.bid_item_id, location: @placed_quantity.location, notes: @placed_quantity.notes, quantity: @placed_quantity.quantity, report_id: @placed_quantity.report_id } }
    assert_redirected_to placed_quantity_url(@placed_quantity)
  end

  test "should destroy placed_quantity" do
    assert_difference("PlacedQuantity.count", -1) do
      delete placed_quantity_url(@placed_quantity)
    end

    assert_redirected_to placed_quantities_url
  end
end
