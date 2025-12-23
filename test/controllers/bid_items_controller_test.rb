require "test_helper"

class BidItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @bid_item = bid_items(:one)
  end

  test "should get index" do
    get bid_items_url
    assert_response :success
  end

  test "should get new" do
    get new_bid_item_url
    assert_response :success
  end

  test "should create bid_item" do
    assert_difference("BidItem.count") do
      post bid_items_url, params: { bid_item: { code: @bid_item.code, description: @bid_item.description, unit: @bid_item.unit } }
    end

    assert_redirected_to bid_item_url(BidItem.last)
  end

  test "should show bid_item" do
    get bid_item_url(@bid_item)
    assert_response :success
  end

  test "should get edit" do
    get edit_bid_item_url(@bid_item)
    assert_response :success
  end

  test "should update bid_item" do
    patch bid_item_url(@bid_item), params: { bid_item: { code: @bid_item.code, description: @bid_item.description, unit: @bid_item.unit } }
    assert_redirected_to bid_item_url(@bid_item)
  end

  test "should destroy bid_item" do
    assert_difference("BidItem.count", -1) do
      delete bid_item_url(@bid_item)
    end

    assert_redirected_to bid_items_url
  end
end
