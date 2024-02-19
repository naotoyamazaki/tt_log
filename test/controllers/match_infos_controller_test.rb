require "test_helper"

class MatchInfosControllerTest < ActionDispatch::IntegrationTest
  setup do
    @match_info = match_infos(:one)
  end

  test "should get index" do
    get match_infos_url
    assert_response :success
  end

  test "should get new" do
    get new_match_info_url
    assert_response :success
  end

  test "should create match_info" do
    assert_difference("MatchInfo.count") do
      post match_infos_url, params: { match_info: { match_date: @match_info.match_date, match_name: @match_info.match_name, memo: @match_info.memo, opponent_id: @match_info.opponent_id, player_id: @match_info.player_id, user_id: @match_info.user_id } }
    end

    assert_redirected_to match_info_url(MatchInfo.last)
  end

  test "should show match_info" do
    get match_info_url(@match_info)
    assert_response :success
  end

  test "should get edit" do
    get edit_match_info_url(@match_info)
    assert_response :success
  end

  test "should update match_info" do
    patch match_info_url(@match_info), params: { match_info: { match_date: @match_info.match_date, match_name: @match_info.match_name, memo: @match_info.memo, opponent_id: @match_info.opponent_id, player_id: @match_info.player_id, user_id: @match_info.user_id } }
    assert_redirected_to match_info_url(@match_info)
  end

  test "should destroy match_info" do
    assert_difference("MatchInfo.count", -1) do
      delete match_info_url(@match_info)
    end

    assert_redirected_to match_infos_url
  end
end
