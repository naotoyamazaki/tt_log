require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#batting_style_abbr_info' do
    it 'ロビングとサーブミスの略称とラベルを返す' do
      expect(helper.batting_style_abbr_info('lobbing')).to eq(abbr: 'Lob', label: 'ロビング')
      expect(helper.batting_style_abbr_info('serve_miss')).to eq(abbr: 'SM', label: 'サーブミス')
    end
  end

  describe '#player_scoring_techniques' do
    it 'sorts by player score and removes empty score rows' do
      scores = [
        build_score(:serve, score: 2, lost_score: 1),
        build_score(:fore_push, score: 5, lost_score: 0),
        build_score(:serve, score: 1, lost_score: 1),
        build_score(:back_push, score: 0, lost_score: 0)
      ]

      result = helper.player_scoring_techniques(scores)

      expect(result.pluck(:batting_style)).to eq(%w[fore_push serve])
      expect(result.first).to include(score: 5, lost_score: 0, rate: 100)
      expect(result.second).to include(score: 3, lost_score: 2, rate: 60)
    end
  end

  describe '#opponent_scoring_techniques' do
    it 'sorts by opponent score and removes empty score rows' do
      scores = [
        build_score(:serve, score: 4, lost_score: 1),
        build_score(:fore_push, score: 1, lost_score: 5),
        build_score(:serve, score: 0, lost_score: 2),
        build_score(:back_push, score: 0, lost_score: 0)
      ]

      result = helper.opponent_scoring_techniques(scores)

      expect(result.pluck(:batting_style)).to eq(%w[fore_push serve])
      expect(result.first).to include(score: 1, lost_score: 5, rate: 17, opponent_rate: 83)
      expect(result.second).to include(score: 4, lost_score: 3, rate: 57, opponent_rate: 43)
    end
  end

  describe '#own_error_techniques' do
    it 'ミス数降順（同数は技術の固定順）で並べ、凡ミス全体に占める割合を付ける' do
      scores = [
        build_score(:fore_push, score: 1, lost_score: 5, own_error_count: 2),
        build_score(:serve, score: 4, lost_score: 1, own_error_count: 2),
        build_score(:fore_drive_vs_topspin, score: 0, lost_score: 0, own_error_count: 4),
        build_score(:back_push, score: 3, lost_score: 3, own_error_count: 0),
        build_score(:serve, score: 1, lost_score: 0, own_error_count: 0)
      ]

      result = helper.own_error_techniques(scores)

      expect(result.pluck(:batting_style)).to eq(%w[fore_drive_vs_topspin serve fore_push])
      expect(result.first).to include(own_error_count: 4, share: 50)
      expect(result.pluck(:own_error_count)).to eq([4, 2, 2])
    end

    it '凡ミスがなければ空配列を返す' do
      expect(helper.own_error_techniques([build_score(:serve, score: 1, lost_score: 1)])).to eq([])
    end

    it '相手の得点技術ランキングには凡ミスが混入しない' do
      scores = [build_score(:serve, score: 0, lost_score: 0, own_error_count: 5)]
      expect(helper.opponent_scoring_techniques(scores)).to eq([])
    end
  end

  def build_score(batting_style, score:, lost_score:, own_error_count: 0)
    Score.new(batting_style: batting_style, score: score, lost_score: lost_score, own_error_count: own_error_count)
  end
end
