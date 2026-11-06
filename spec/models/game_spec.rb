require 'rails_helper'

RSpec.describe Game, type: :model do
  describe 'enums' do
    it { is_expected.to define_enum_for(:first_server).with_values(player: 0, opponent: 1) }
  end

  describe '#recalculate_scores' do
    it 'opponent_score は lost_score と own_error_count の合計になる' do
      game = create(:game)
      create(:score, match_info: game.match_info, game: game, batting_style: :serve, score: 3, lost_score: 2,
                     own_error_count: 0)
      create(:score, match_info: game.match_info, game: game, batting_style: :fore_push, score: 1, lost_score: 1,
                     own_error_count: 2)
      game.recalculate_scores
      expect(game.reload.player_score).to eq(4)
      expect(game.opponent_score).to eq(5)
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:match_info) }
    it { is_expected.to have_many(:scores).dependent(:destroy) }
    it { is_expected.to have_many(:rallies).dependent(:destroy) }
  end
end
