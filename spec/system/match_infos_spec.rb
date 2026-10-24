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

  describe '対戦相手タイプ属性の入力（Sprint 2）' do
    let!(:match_info) { create(:match_info, user: user) }

    before do
      page.driver.post login_path, email: user.email, password: 'password'
    end

    it '各selectを選択して保存すると値が保持される' do
      visit edit_match_info_path(match_info)

      select '左利き', from: '利き手'
      select 'ペンホルダー', from: 'ラケット'
      select '粒高', from: 'ラバー（フォア）'
      select 'アンチ', from: 'ラバー（バック）'
      select 'カットマン', from: '戦型'

      click_button '🚀 試合を分析する'

      visit edit_match_info_path(match_info)

      expect(page).to have_select('利き手', selected: '左利き')
      expect(page).to have_select('ラケット', selected: 'ペンホルダー')
      expect(page).to have_select('ラバー（フォア）', selected: '粒高')
      expect(page).to have_select('ラバー（バック）', selected: 'アンチ')
      expect(page).to have_select('戦型', selected: 'カットマン')
    end

    it '戦型で「その他」を選択するとテキスト欄に自由入力できる' do
      visit edit_match_info_path(match_info)

      select 'その他', from: '戦型'
      fill_in '戦型（その他・自由入力）', with: '異質型'

      click_button '🚀 試合を分析する'

      expect(match_info.reload.opponent_playstyle_other).to eq('異質型')
    end

    it '未設定のまま保存してもエラーにならない' do
      visit edit_match_info_path(match_info)

      click_button '🚀 試合を分析する'

      expect(page).to have_no_content('エラー')
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
