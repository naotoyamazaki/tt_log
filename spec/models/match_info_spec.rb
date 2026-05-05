# spec/models/match_info_spec.rb
require 'rails_helper'

RSpec.describe MatchInfo, type: :model do
  describe "バリデーション" do
    it "有効な属性で有効になること" do
      match_info = FactoryBot.build(:match_info)
      expect(match_info).to be_valid
    end

    it "match_dateが無いと無効になること" do
      match_info = FactoryBot.build(:match_info, match_date: nil)
      expect(match_info).to be_invalid
      expect(match_info.errors[:match_date]).to include("を入力してください")
    end

    it "match_nameが無いと無効になること" do
      match_info = FactoryBot.build(:match_info, match_name: nil)
      expect(match_info).to be_invalid
      expect(match_info.errors[:match_name]).to include("を入力してください")
    end

    it "memoが500文字を超えると無効になること" do
      long_memo = "a" * 501
      match_info = FactoryBot.build(:match_info, memo: long_memo)
      expect(match_info).to be_invalid
      expect(match_info.errors[:memo]).to include(I18n.t('errors.messages.memo_too_long'))
    end

    it "player_nameが空だと無効になること" do
      match_info = FactoryBot.build(:match_info, player_name: "")
      expect(match_info).to be_invalid
      expect(match_info.errors[:player_name]).to include(I18n.t('errors.messages.blank'))
    end

    it "opponent_nameが空だと無効になること" do
      match_info = FactoryBot.build(:match_info, opponent_name: "")
      expect(match_info).to be_invalid
      expect(match_info.errors[:opponent_name]).to include(I18n.t('errors.messages.blank'))
    end
  end

  describe "#game_by_game_score_data" do
    let(:match_info) { create(:match_info) }

    context "ゲームデータがない場合" do
      it "空配列を返すこと" do
        expect(match_info.game_by_game_score_data).to eq([])
      end
    end

    context "ゲームデータがある場合" do
      let!(:game1) { create(:game, match_info: match_info, game_number: 1, player_score: 11, opponent_score: 8) }
      let!(:game2) { create(:game, match_info: match_info, game_number: 2, player_score: 7, opponent_score: 11) }

      before do
        create(:score, match_info: match_info, game: game1,
                       batting_style: :fore_drive_vs_topspin, score: 5, lost_score: 2)
        create(:score, match_info: match_info, game: game2,
                       batting_style: :fore_drive_vs_topspin, score: 2, lost_score: 4)
      end

      it "ゲーム番号順にデータを返すこと" do
        data = match_info.game_by_game_score_data
        expect(data.length).to eq(2)
        expect(data[0][:game_number]).to eq(1)
        expect(data[1][:game_number]).to eq(2)
      end

      it "スコアと勝敗結果を含むこと" do
        data = match_info.game_by_game_score_data
        expect(data[0][:score]).to eq("11-8")
        expect(data[0][:result]).to eq("勝ち")
        expect(data[1][:score]).to eq("7-11")
        expect(data[1][:result]).to eq("負け")
      end

      it "技術別データを含むこと" do
        data = match_info.game_by_game_score_data
        expect(data[0][:techniques]).to be_an(Array)
        expect(data[0][:techniques].first).to include("得点")
        expect(data[0][:techniques].first).to include("失点")
      end
    end
  end
end
