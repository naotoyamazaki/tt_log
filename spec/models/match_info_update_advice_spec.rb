require 'rails_helper'

RSpec.describe MatchInfo, type: :model do
  describe "#update_advice" do
    let(:match_info) { create(:match_info) }

    it "正常にアドバイスを更新する" do
      match_info.update_advice("この技術を強化しましょう")
      expect(match_info.reload.advice).to eq("この技術を強化しましょう")
    end

    it "updateで例外が発生したら rescue され、ログ出力される" do
      allow(match_info).to receive(:update).and_raise(ActiveRecord::RecordInvalid.new(match_info))
      expect(Rails.logger).to receive(:error).with(/Failed to update advice:/)

      match_info.update_advice("失敗テスト")
    end
  end
end
