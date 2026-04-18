# spec/system/match_infos_spec.rb
require 'rails_helper'

RSpec.describe '試合情報の投稿', type: :system do
  let(:user) { create(:user) }

  before do
    driven_by(:rack_test)
  end

  it 'ユーザーが試合情報を投稿し、詳細ページに表示される' do
    visit login_path
    fill_in 'メールアドレス', with: user.email
    fill_in 'パスワード', with: 'password'
    click_button 'ログイン'

    visit new_match_info_path

    fill_in '🗓️日付', with: Time.zone.today
    fill_in '🏆大会名', with: 'テスト大会'
    fill_in '👤選手名', with: '田中'
    fill_in '👤対戦相手名', with: '佐藤'
    fill_in '🗒️メモ', with: 'テストメモです'

    # game_scores[serve][score] など固定の名前でフィールドが並んでいる
    all('input[name$="[score]"]')[0].fill_in with: 3
    all('input[name$="[lost_score]"]')[0].fill_in with: 1

    all('input[name$="[score]"]')[1].fill_in with: 2
    all('input[name$="[lost_score]"]')[1].fill_in with: 1

    click_button '🚀 試合を分析する'

    expect(page).to have_content 'テスト大会'
    expect(page).to have_content '田中'
    expect(page).to have_content '佐藤'
    expect(page).to have_content 'テストメモです'
  end
end
