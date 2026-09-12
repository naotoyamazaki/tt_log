# spec/system/serve_receive_onboarding_spec.rb
require 'rails_helper'

RSpec.describe 'サーブ・レシーブ分析の導線強化（Sprint 1）', type: :system do
  let(:user) { create(:user) }

  before do
    driven_by(:rack_test)
    page.driver.post login_path, email: user.email, password: 'password'
  end

  it '一覧ページのサーブ・レシーブ分析ボタンにNEWバッジが表示される' do
    visit match_infos_path

    serve_receive_button = find('a.btn.btn-primary', text: 'サーブ・レシーブ分析を開始')
    expect(serve_receive_button).to have_content('NEW')
  end

  it 'ヘッダーのドロップダウンからサーブ・レシーブ分析の新規作成ページへ遷移できる' do
    visit match_infos_path

    click_link 'サーブ・レシーブ分析を開始', href: new_serve_receive_match_infos_path, match: :first

    expect(page).to have_current_path(new_serve_receive_match_infos_path)
  end

  it 'ヘッダードロップダウンに両方の分析の説明サブテキストが表示される' do
    visit match_infos_path

    expect(page).to have_content('技術別の得失点を記録')
    expect(page).to have_content('3球目・4球目パターンを分析')
  end
end
