require "application_system_test_case"

class InspectionEntriesTest < ApplicationSystemTestCase
  setup do
    @inspection_entry = inspection_entries(:one)
  end

  test "visiting the index" do
    visit inspection_entries_url
    assert_selector "h1", text: "Inspection entries"
  end

  test "should create inspection entry" do
    visit inspection_entries_url
    click_on "New inspection entry"

    fill_in "Bid item", with: @inspection_entry.bid_item_id
    fill_in "Location", with: @inspection_entry.location
    fill_in "Notes", with: @inspection_entry.notes
    fill_in "Quantity", with: @inspection_entry.quantity
    fill_in "Report", with: @inspection_entry.report_id
    click_on "Create Inspection entry"

    assert_text "Inspection entry was successfully created"
    click_on "Back"
  end

  test "should update Inspection entry" do
    visit inspection_entry_url(@inspection_entry)
    click_on "Edit this inspection entry", match: :first

    fill_in "Bid item", with: @inspection_entry.bid_item_id
    fill_in "Location", with: @inspection_entry.location
    fill_in "Notes", with: @inspection_entry.notes
    fill_in "Quantity", with: @inspection_entry.quantity
    fill_in "Report", with: @inspection_entry.report_id
    click_on "Update Inspection entry"

    assert_text "Inspection entry was successfully updated"
    click_on "Back"
  end

  test "should destroy Inspection entry" do
    visit inspection_entry_url(@inspection_entry)
    click_on "Destroy this inspection entry", match: :first

    assert_text "Inspection entry was successfully destroyed"
  end
end
