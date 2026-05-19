# spec/system/match_infos_spec.rb
require 'rails_helper'

RSpec.describe '試合情報の投稿', type: :system do
  let(:user) { create(:user) }

  before do
    driven_by(:rack_test)
  end

  describe 'ゲーム別スコア表示（F8/F9）' do
    let(:match_info) { create(:match_info, user: user) }

    before do
      create(:game, match_info: match_info, game_number: 1, player_score: 11, opponent_score: 8)
      create(:game, match_info: match_info, game_number: 2, player_score: 7, opponent_score: 11)
      allow(ChatgptService).to receive(:get_advice).and_return("テストアドバイス")
    end

    it '詳細ページにゲーム別スコアが表示される' do
      visit login_path
      fill_in 'メールアドレス', with: user.email
      fill_in 'パスワード', with: 'password'
      click_button 'ログイン'

      visit match_info_path(match_info)

      expect(page).to have_content('ゲーム別スコア')
      expect(page).to have_content('11-8')
      expect(page).to have_content('7-11')
    end

    it '一覧ページのカードにゲーム数が表示される' do
      visit login_path
      fill_in 'メールアドレス', with: user.email
      fill_in 'パスワード', with: 'password'
      click_button 'ログイン'

      visit match_infos_path

      expect(page).to have_content('1-1')
    end
  end

  it 'ユーザーが試合情報を投稿し、詳細ページに表示される' do
    # rack_test ドライバで直接 POST してセッションを維持したまま詳細ページを確認する
    page.driver.post login_path, email: user.email, password: 'password'

    rallies = [
      { 'winner' => 'player', 'batting_style' => 'serve' },
      { 'winner' => 'opponent', 'batting_style' => 'serve' }
    ]
    page.driver.post match_infos_path, {
      match_info: {
        match_date: Time.zone.today,
        match_name: 'テスト大会',
        memo: 'テストメモです',
        match_format: 5,
        player_name: '田中',
        opponent_name: '佐藤'
      },
      rallies: rallies.to_json
    }

    match_info = MatchInfo.last
    visit match_info_path(match_info)

    expect(page).to have_content 'テスト大会'
    expect(page).to have_content '田中'
    expect(page).to have_content '佐藤'
    expect(page).to have_content 'テストメモです'
  end
end
