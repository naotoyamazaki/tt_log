require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
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

  def build_score(batting_style, score:, lost_score:)
    Score.new(batting_style: batting_style, score: score, lost_score: lost_score)
  end
end
