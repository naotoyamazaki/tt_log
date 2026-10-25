require 'rails_helper'

RSpec.describe OpponentTypeWinRateAggregator do
  let(:user) { create(:user) }

  def match_info_with_games(opponent_playstyle, game_results)
    match_info = create(:match_info, user: user, opponent_playstyle: opponent_playstyle)
    game_results.each_with_index do |(player_score, opponent_score), index|
      create(:game, match_info: match_info, game_number: index + 1,
                    player_score: player_score, opponent_score: opponent_score)
    end
    match_info
  end

  describe "#type_win_rates" do
    it "試合が1件もない場合は空配列を返すこと" do
      match_infos = user.match_infos.includes(:games)

      result = described_class.new(match_infos: match_infos, attribute: :opponent_playstyle).type_win_rates

      expect(result).to eq([])
    end

    it "全て同じ戦型の場合、その戦型1件分の試合数・勝数・敗数・勝率が算出されること" do
      match_info_with_games(:cutman, [[11, 5], [11, 9]]) # 勝ち
      match_info_with_games(:cutman, [[5, 11], [9, 11]]) # 負け

      match_infos = user.match_infos.includes(:games)
      result = described_class.new(match_infos: match_infos, attribute: :opponent_playstyle).type_win_rates

      expect(result).to eq(
        [
          { type_label: "カットマン", match_count: 2, win_count: 1, lose_count: 1, win_rate: 50 }
        ]
      )
    end

    it "複数戦型が混在する場合、戦型ごとに分けて勝率が算出されること" do
      match_info_with_games(:cutman, [[11, 5], [11, 9]]) # 勝ち
      match_info_with_games(:cutman, [[11, 5], [11, 9]]) # 勝ち
      match_info_with_games(:front_drive, [[5, 11], [9, 11]]) # 負け

      match_infos = user.match_infos.includes(:games)
      result = described_class.new(match_infos: match_infos, attribute: :opponent_playstyle).type_win_rates

      cutman_entry = result.find { |entry| entry[:type_label] == "カットマン" }
      front_drive_entry = result.find { |entry| entry[:type_label] == "前陣ドライブ型" }

      expect(cutman_entry).to eq(
        { type_label: "カットマン", match_count: 2, win_count: 2, lose_count: 0, win_rate: 100 }
      )
      expect(front_drive_entry).to eq(
        { type_label: "前陣ドライブ型", match_count: 1, win_count: 0, lose_count: 1, win_rate: 0 }
      )
    end

    it "戦型が未設定の試合は集計対象外になること" do
      match_info_with_games(nil, [[11, 5], [11, 9]])

      match_infos = user.match_infos.includes(:games)
      result = described_class.new(match_infos: match_infos, attribute: :opponent_playstyle).type_win_rates

      expect(result).to eq([])
    end

    it "引き分け（勝敗未確定）の試合は集計対象外になること" do
      match_info_with_games(:cutman, [[11, 9], [9, 11]]) # 1-1で引き分け

      match_infos = user.match_infos.includes(:games)
      result = described_class.new(match_infos: match_infos, attribute: :opponent_playstyle).type_win_rates

      expect(result).to eq([])
    end
  end
end
