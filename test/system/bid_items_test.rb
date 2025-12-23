require "application_system_test_case"

class BidItemsTest < ApplicationSystemTestCase
  setup do
    @bid_item = bid_items(:one)
  end

  test "visiting the index" do
    visit bid_items_url
    assert_selector "h1", text: "Bid items"
  end

  test "should create bid item" do
    visit bid_items_url
    click_on "New bid item"

    fill_in "Code", with: @bid_item.code
    fill_in "Description", with: @bid_item.description
    fill_in "Unit", with: @bid_item.unit
    click_on "Create Bid item"

    assert_text "Bid item was successfully created"
    click_on "Back"
  end

  test "should update Bid item" do
    visit bid_item_url(@bid_item)
    click_on "Edit this bid item", match: :first

    fill_in "Code", with: @bid_item.code
    fill_in "Description", with: @bid_item.description
    fill_in "Unit", with: @bid_item.unit
    click_on "Update Bid item"

    assert_text "Bid item was successfully updated"
    click_on "Back"
  end

  test "should destroy Bid item" do
    visit bid_item_url(@bid_item)
    click_on "Destroy this bid item", match: :first

    assert_text "Bid item was successfully destroyed"
  end
end
