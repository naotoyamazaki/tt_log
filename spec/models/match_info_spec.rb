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
end
