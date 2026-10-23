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

  describe "analysis_type enum" do
    it "デフォルトでtechniqueであること" do
      match_info = FactoryBot.create(:match_info)
      expect(match_info.technique?).to be true
    end

    it "serve_receiveに変更できること" do
      match_info = FactoryBot.create(:match_info)
      match_info.serve_receive!
      expect(match_info.serve_receive?).to be true
    end
  end

  describe ".completed" do
    it "draft: falseの試合のみを返すこと" do
      completed_match_info = FactoryBot.create(:match_info, draft: false)
      FactoryBot.create(:match_info, draft: true)

      expect(MatchInfo.completed).to eq([completed_match_info])
    end
  end

  describe "serve_receive_patterns関連" do
    it "has_many serve_receive_patternsを持つこと" do
      match_info = FactoryBot.create(:match_info)
      expect(match_info).to respond_to(:serve_receive_patterns)
    end
  end

  describe "対戦相手タイプ属性" do
    it "未設定（nil）でも保存できること" do
      match_info = FactoryBot.create(:match_info)
      expect(match_info.opponent_handedness).to be_nil
      expect(match_info.opponent_racket).to be_nil
      expect(match_info.opponent_rubber_forehand).to be_nil
      expect(match_info.opponent_rubber_backhand).to be_nil
      expect(match_info.opponent_playstyle).to be_nil
      expect(match_info.opponent_playstyle_other).to be_nil
    end

    it "opponent_handednessの各値を設定・保存できること" do
      %i[right left].each do |value|
        match_info = FactoryBot.create(:match_info, opponent_handedness: value)
        expect(match_info.reload.opponent_handedness).to eq(value.to_s)
      end
    end

    it "opponent_racketの各値を設定・保存できること" do
      %i[shakehand penholder].each do |value|
        match_info = FactoryBot.create(:match_info, opponent_racket: value)
        expect(match_info.reload.opponent_racket).to eq(value.to_s)
      end
    end

    it "opponent_rubber_forehandの各値を設定・保存できること" do
      %i[backside pips_out pips_long anti].each do |value|
        match_info = FactoryBot.create(:match_info, opponent_rubber_forehand: value)
        expect(match_info.reload.opponent_rubber_forehand).to eq(value.to_s)
      end
    end

    it "opponent_rubber_backhandの各値を設定・保存できること" do
      %i[backside pips_out pips_long anti none].each do |value|
        match_info = FactoryBot.create(:match_info, opponent_rubber_backhand: value)
        expect(match_info.reload.opponent_rubber_backhand).to eq(value.to_s)
      end
    end

    it "opponent_playstyleの各値を設定・保存できること" do
      %i[front_drive mid_drive front_hit blocker cutman other].each do |value|
        match_info = FactoryBot.create(:match_info, opponent_playstyle: value)
        expect(match_info.reload.opponent_playstyle).to eq(value.to_s)
      end
    end

    it "opponent_playstyle_otherを任意の文字列として保存できること" do
      match_info = FactoryBot.create(:match_info, opponent_playstyle: :other, opponent_playstyle_other: "カットマンもどき")
      expect(match_info.reload.opponent_playstyle_other).to eq("カットマンもどき")
    end

    it "opponent_playstyleがother以外でもopponent_playstyle_otherの値が残っていても保存できること" do
      match_info = FactoryBot.create(:match_info, opponent_playstyle: :cutman, opponent_playstyle_other: "メモ")
      expect(match_info.reload.opponent_playstyle_other).to eq("メモ")
    end
  end

  describe ".human_enum_name" do
    it "opponent_handednessの和名を返すこと" do
      expect(MatchInfo.human_enum_name(:opponent_handedness, "right")).to eq("右利き")
      expect(MatchInfo.human_enum_name(:opponent_handedness, "left")).to eq("左利き")
    end

    it "opponent_playstyleの和名を返すこと" do
      expect(MatchInfo.human_enum_name(:opponent_playstyle, "cutman")).to eq("カットマン")
      expect(MatchInfo.human_enum_name(:opponent_playstyle, "other")).to eq("その他")
    end
  end

  describe "#result" do
    let(:match_info) { FactoryBot.create(:match_info) }

    it "試合が無い場合nilを返すこと" do
      expect(match_info.result).to be_nil
    end

    it "獲得ゲーム数が多い場合winを返すこと" do
      FactoryBot.create(:game, match_info: match_info, game_number: 1, player_score: 11, opponent_score: 8)
      FactoryBot.create(:game, match_info: match_info, game_number: 2, player_score: 11, opponent_score: 9)
      expect(match_info.result).to eq(:win)
    end

    it "獲得ゲーム数が少ない場合loseを返すこと" do
      FactoryBot.create(:game, match_info: match_info, game_number: 1, player_score: 8, opponent_score: 11)
      FactoryBot.create(:game, match_info: match_info, game_number: 2, player_score: 9, opponent_score: 11)
      expect(match_info.result).to eq(:lose)
    end

    it "獲得ゲーム数が同じ場合nilを返すこと" do
      FactoryBot.create(:game, match_info: match_info, game_number: 1, player_score: 11, opponent_score: 8)
      FactoryBot.create(:game, match_info: match_info, game_number: 2, player_score: 8, opponent_score: 11)
      expect(match_info.result).to be_nil
    end
  end
end
