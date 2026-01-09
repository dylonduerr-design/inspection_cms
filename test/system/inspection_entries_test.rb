require "application_system_test_case"

class InspectionEntriesTest < ApplicationSystemTestCase
  setup do
    @placed_quantity = placed_quantities(:one)
  end

  test "visiting the index" do
    visit placed_quantities_url
    assert_selector "h1", text: "Inspection entries"
  end

  test "should create inspection entry" do
    visit placed_quantities_url
    click_on "New inspection entry"

    fill_in "Bid item", with: @placed_quantity.bid_item_id
    fill_in "Location", with: @placed_quantity.location
    fill_in "Notes", with: @placed_quantity.notes
    fill_in "Quantity", with: @placed_quantity.quantity
    fill_in "Report", with: @placed_quantity.report_id
    click_on "Create Inspection entry"

    assert_text "Inspection entry was successfully created"
    click_on "Back"
  end

  test "should update Inspection entry" do
    visit placed_quantity_url(@placed_quantity)
    click_on "Edit this inspection entry", match: :first

    fill_in "Bid item", with: @placed_quantity.bid_item_id
    fill_in "Location", with: @placed_quantity.location
    fill_in "Notes", with: @placed_quantity.notes
    fill_in "Quantity", with: @placed_quantity.quantity
    fill_in "Report", with: @placed_quantity.report_id
    click_on "Update Inspection entry"

    assert_text "Inspection entry was successfully updated"
    click_on "Back"
  end

  test "should destroy Inspection entry" do
    visit placed_quantity_url(@placed_quantity)
    click_on "Destroy this inspection entry", match: :first

    assert_text "Inspection entry was successfully destroyed"
  end
end
