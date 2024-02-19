require "application_system_test_case"

class MatchInfosTest < ApplicationSystemTestCase
  setup do
    @match_info = match_infos(:one)
  end

  test "visiting the index" do
    visit match_infos_url
    assert_selector "h1", text: "Match infos"
  end

  test "should create match info" do
    visit match_infos_url
    click_on "New match info"

    fill_in "Match date", with: @match_info.match_date
    fill_in "Match name", with: @match_info.match_name
    fill_in "Memo", with: @match_info.memo
    fill_in "Opponent", with: @match_info.opponent_id
    fill_in "Player", with: @match_info.player_id
    fill_in "User", with: @match_info.user_id
    click_on "Create Match info"

    assert_text "Match info was successfully created"
    click_on "Back"
  end

  test "should update Match info" do
    visit match_info_url(@match_info)
    click_on "Edit this match info", match: :first

    fill_in "Match date", with: @match_info.match_date
    fill_in "Match name", with: @match_info.match_name
    fill_in "Memo", with: @match_info.memo
    fill_in "Opponent", with: @match_info.opponent_id
    fill_in "Player", with: @match_info.player_id
    fill_in "User", with: @match_info.user_id
    click_on "Update Match info"

    assert_text "Match info was successfully updated"
    click_on "Back"
  end

  test "should destroy Match info" do
    visit match_info_url(@match_info)
    click_on "Destroy this match info", match: :first

    assert_text "Match info was successfully destroyed"
  end
end
