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

  it 'ヘッダーの文言が更新されている' do
    visit match_infos_path

    expect(page).to have_content('分析結果一覧')
    expect(page).to have_content('技術別得点率分析を開始')
  end

  it 'PC用ドロップダウンとモバイル用直接リンクの両方がDOMに存在する' do
    visit match_infos_path

    expect(page).to have_css('li.dropdown.d-none.d-lg-block')
    expect(page).to have_css('li.nav-item.d-lg-none', minimum: 3)
    within('li.dropdown.d-none.d-lg-block') do
      expect(page).to have_link('分析結果一覧', href: match_infos_path)
      expect(page).to have_link('サーブ・レシーブ分析を開始', href: new_serve_receive_match_infos_path)
    end
  end

  it '「2つの分析の違いは？」をクリックすると説明カードが表示され両機能の説明文を含む' do
    visit match_infos_path

    expect(page).to have_css('#analysisIntro.collapse', visible: :all)

    click_link '2つの分析の違いは？'

    within('#analysisIntro') do
      expect(page).to have_content('技術別得点率分析')
      expect(page).to have_content('得点・失点した技術を記録しAIが技術面のアドバイスを生成')
      expect(page).to have_content('サーブ・レシーブ分析')
      expect(page).to have_content('サーブ/レシーブ直後の3球目・4球目をパターン別で記録し')
    end
  end

  it '技術別得点率分析の新規作成ページに機能説明が表示される（Sprint 3）' do
    visit new_match_info_path

    expect(page).to have_content('打法ごとの得点・失点を記録して、AIが技術面のアドバイスを行います')
  end

  it 'サーブ・レシーブ分析の新規作成ページに機能説明が表示される（Sprint 3）' do
    visit new_serve_receive_match_infos_path

    expect(page).to have_content('サーブ/レシーブ直後の3球目・4球目パターンごとの得点率を分析します')
  end

  it 'サーブ・レシーブ分析が空状態のとき、機能説明と新規作成ページへの導線が表示される（Sprint 3）' do
    srp_match_info = create(:match_info, user: user, analysis_type: :serve_receive)

    visit match_info_path(srp_match_info)

    expect(page).to have_content('まだ得点データがありません')
    expect(page).to have_content('3球目・4球目パターンごとの得点率')
    expect(page).to have_link('サーブ・レシーブ分析を始める', href: new_serve_receive_match_infos_path)
  end
end
