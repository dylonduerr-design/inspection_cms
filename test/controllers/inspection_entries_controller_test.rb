require "test_helper"

class InspectionEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @inspection_entry = inspection_entries(:one)
  end

  test "should get index" do
    get inspection_entries_url
    assert_response :success
  end

  test "should get new" do
    get new_inspection_entry_url
    assert_response :success
  end

  test "should create inspection_entry" do
    assert_difference("InspectionEntry.count") do
      post inspection_entries_url, params: { inspection_entry: { bid_item_id: @inspection_entry.bid_item_id, location: @inspection_entry.location, notes: @inspection_entry.notes, quantity: @inspection_entry.quantity, report_id: @inspection_entry.report_id } }
    end

    assert_redirected_to inspection_entry_url(InspectionEntry.last)
  end

  test "should show inspection_entry" do
    get inspection_entry_url(@inspection_entry)
    assert_response :success
  end

  test "should get edit" do
    get edit_inspection_entry_url(@inspection_entry)
    assert_response :success
  end

  test "should update inspection_entry" do
    patch inspection_entry_url(@inspection_entry), params: { inspection_entry: { bid_item_id: @inspection_entry.bid_item_id, location: @inspection_entry.location, notes: @inspection_entry.notes, quantity: @inspection_entry.quantity, report_id: @inspection_entry.report_id } }
    assert_redirected_to inspection_entry_url(@inspection_entry)
  end

  test "should destroy inspection_entry" do
    assert_difference("InspectionEntry.count", -1) do
      delete inspection_entry_url(@inspection_entry)
    end

    assert_redirected_to inspection_entries_url
  end
end
