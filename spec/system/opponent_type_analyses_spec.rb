require 'rails_helper'

RSpec.describe '対戦相手タイプ別分析（Sprint 4）', type: :system do
  let(:user) { create(:user) }

  before do
    driven_by(:rack_test)
    page.driver.post login_path, email: user.email, password: 'password'
  end

  describe 'ヘッダーからの遷移' do
    it 'ヘッダーの「対戦相手タイプ別分析」リンクから遷移できること' do
      visit match_infos_path

      click_link '対戦相手タイプ別分析', match: :first

      expect(page).to have_content('対戦相手タイプ別分析')
      expect(page).to have_content('この戦型との対戦成績')
    end
  end

  describe '戦型セレクトの切り替え' do
    before do
      cutman_match_info = create(:match_info, user: user, opponent_playstyle: :cutman)
      create(:game, match_info: cutman_match_info, game_number: 1, player_score: 11, opponent_score: 5)
      create(:game, match_info: cutman_match_info, game_number: 2, player_score: 11, opponent_score: 5)

      blocker_match_info = create(:match_info, user: user, opponent_playstyle: :blocker)
      create(:game, match_info: blocker_match_info, game_number: 1, player_score: 5, opponent_score: 11)
      create(:game, match_info: blocker_match_info, game_number: 2, player_score: 5, opponent_score: 11)
    end

    it '戦型セレクトを切り替えると表示内容が切り替わること' do
      visit opponent_type_analysis_path(opponent_playstyle: 'cutman')
      expect(page).to have_content('100%')

      select 'ブロック型', from: '🤝戦型を選択'

      expect(page).to have_content('0%')
    end
  end
end
