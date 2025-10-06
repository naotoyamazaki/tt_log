# spec/models/match_info_batting_score_data_spec.rb
require 'rails_helper'

RSpec.describe MatchInfo, type: :model do
  describe "#batting_score_data" do
    it "サーブを含め、技術別のスコアデータを集計して返す（レシーブは対象外）" do
      match_info = create(:match_info)
      create(:score, match_info: match_info, batting_style: :serve,       score: 3, lost_score: 2)
      create(:score, match_info: match_info, batting_style: :fore_drive,  score: 5, lost_score: 1)
      create(:score, match_info: match_info, batting_style: :back_push,   score: 2, lost_score: 4)

      data = match_info.batting_score_data

      expect(data.join).to include("サーブ")
      expect(data.join).to include("フォアドライブ")
      expect(data.join).to include("バックツッツキ")
    end
  end
end
