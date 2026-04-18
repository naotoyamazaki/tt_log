require 'rails_helper'

RSpec.describe ChatgptService do
  describe ".get_advice" do
    let(:batting_score_data) { '["フォアドライブ：得点 5 失点 2"]' }
    let(:success_body) do
      {
        "choices" => [
          { "message" => { "content" => "テストアドバイス" } }
        ]
      }.to_json
    end
    let(:mock_response) { instance_double(Net::HTTPSuccess, is_a?: true, body: success_body) }

    before do
      allow(Net::HTTP).to receive(:post).and_return(mock_response)
      allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    end

    context "ゲーム別データなし" do
      it "アドバイスを返すこと" do
        result = described_class.get_advice(batting_score_data)
        expect(result).to eq("テストアドバイス")
      end
    end

    context "ゲーム別データあり" do
      let(:game_data) do
        [
          {
            game_number: 1,
            score: "11-8",
            result: "勝ち",
            techniques: ["フォアドライブ：得点 5 失点 2"]
          }
        ]
      end

      it "ゲーム別データを含めてAPIを呼び出すこと" do
        described_class.get_advice(batting_score_data, game_data)
        expect(Net::HTTP).to have_received(:post) do |_uri, body_json, _headers|
          body = JSON.parse(body_json)
          content = body.dig("messages", 1, "content")
          expect(content).to include("ゲーム別データ")
          expect(content).to include("第1ゲーム")
          expect(content).to include("11-8")
        end
      end

      it "アドバイスを返すこと" do
        result = described_class.get_advice(batting_score_data, game_data)
        expect(result).to eq("テストアドバイス")
      end
    end
  end
end
