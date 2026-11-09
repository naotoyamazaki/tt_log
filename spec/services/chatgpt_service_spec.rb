require 'rails_helper'

RSpec.describe ChatgptService do
  describe ".get_advice" do
    let(:user) { create(:user) }
    let(:match_info) { create(:match_info, user: user) }
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

    context "ralliesが空（旧来データのみ）の場合" do
      it "アドバイスを返すこと" do
        result = described_class.get_advice(match_info)
        expect(result).to eq("テストアドバイス")
      end

      it "旧来プロンプトを使用すること" do
        described_class.get_advice(match_info)
        expect(Net::HTTP).to have_received(:post) do |_uri, body_json, _headers|
          content = JSON.parse(body_json).dig("messages", 1, "content")
          expect(content).to include("得点数と失点数データ")
        end
      end
    end

    context "ralliesが存在する場合" do
      let(:game) do
        create(:game, match_info: match_info, game_number: 1,
                      player_score: 11, opponent_score: 8, first_server: :player)
      end

      before do
        create(:rally, match_info: match_info, game: game, game_number: 1,
                       sequence_number: 1, winner: :player, batting_style: :serve)
        create(:rally, match_info: match_info, game: game, game_number: 1,
                       sequence_number: 2, winner: :opponent, batting_style: :serve)
      end

      it "アドバイスを返すこと" do
        result = described_class.get_advice(match_info)
        expect(result).to eq("テストアドバイス")
      end

      it "ラリーベースのプロンプトを使用すること" do
        described_class.get_advice(match_info)
        expect(Net::HTTP).to have_received(:post) do |_uri, body_json, _headers|
          content = JSON.parse(body_json).dig("messages", 1, "content")
          expect(content).to include("技術別得点効率")
          expect(content).to include("サーブ・レシーブ局面分析")
          expect(content).to include("ゲームごとの技術の流れ")
          expect(content).to include("得点/失点ラッシュと試合パターン")
          expect(content).to include("スコア状況別分析（接戦・デュース）")
        end
      end

      it "max_completion_tokensが2500であること" do
        described_class.get_advice(match_info)
        expect(Net::HTTP).to have_received(:post) do |_uri, body_json, _headers|
          body = JSON.parse(body_json)
          expect(body["max_completion_tokens"]).to eq(2500)
        end
      end

      it "凡ミスがなければ【自分の凡ミス】セクションを出力しないこと" do
        described_class.get_advice(match_info)
        expect(Net::HTTP).to have_received(:post) do |_uri, body_json, _headers|
          content = JSON.parse(body_json).dig("messages", 1, "content")
          expect(content).not_to include("【自分の凡ミス（ミスが多い")
        end
      end

      context "凡ミスのラリーがある場合" do
        before do
          create(:rally, match_info: match_info, game: game, game_number: 1, sequence_number: 3,
                         winner: :opponent, point_type: :own_error, batting_style: :serve_miss)
        end

        it "凡ミスセクションを含め、サーブミスも対象に含めること" do
          described_class.get_advice(match_info)
          expect(Net::HTTP).to have_received(:post) do |_uri, body_json, _headers|
            content = JSON.parse(body_json).dig("messages", 1, "content")
            expect(content).to include("【自分の凡ミス（ミスが多い上位3技術。相手の好プレーとは別）】")
            expect(content).to include("サーブミス: 1件（凡ミス全体の100%）")
          end
        end

        it "システムプロンプトで原因を推測しない方針を伝えること" do
          described_class.get_advice(match_info)
          expect(Net::HTTP).to have_received(:post) do |_uri, body_json, _headers|
            system = JSON.parse(body_json).dig("messages", 0, "content")
            expect(system).to include("相手の好プレー")
            expect(system).to include("原因")
            expect(system).to include("推測してはいけません")
          end
        end
      end
    end
  end
end
