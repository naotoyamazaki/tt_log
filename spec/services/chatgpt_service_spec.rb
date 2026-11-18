require 'rails_helper'

RSpec.describe ChatgptService do
  describe ".get_advice" do
    let(:user) { create(:user) }
    let(:match_info) { create(:match_info, user: user) }
    let(:ok_result) { OpenaiClient::Result.new(content: "テストアドバイス", duration_ms: 10) }

    before { allow(OpenaiClient).to receive(:chat).and_return(ok_result) }

    context "APIが失敗した場合" do
      before do
        allow(OpenaiClient).to receive(:chat)
          .and_return(OpenaiClient::Result.new(error_kind: "timeout", duration_ms: 10))
      end

      it "失敗文言ではなく nil を返すこと" do
        expect(described_class.get_advice(match_info)).to be_nil
      end
    end

    context "ralliesが空（旧来データのみ）の場合" do
      it "アドバイスを返すこと" do
        result = described_class.get_advice(match_info)
        expect(result).to eq("テストアドバイス")
      end

      it "旧来プロンプトを使用すること" do
        described_class.get_advice(match_info)
        expect(OpenaiClient).to have_received(:chat) do |**kwargs|
          content = kwargs[:user_prompt]
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
        expect(OpenaiClient).to have_received(:chat) do |**kwargs|
          content = kwargs[:user_prompt]
          expect(content).to include("技術別得点効率")
          expect(content).to include("サーブ・レシーブ局面分析")
          expect(content).to include("ゲームごとの技術の流れ")
          expect(content).to include("得点/失点ラッシュと試合パターン")
          expect(content).to include("スコア状況別分析（接戦・デュース）")
        end
      end

      it "max_completion_tokensが2500であること" do
        described_class.get_advice(match_info)
        expect(OpenaiClient).to have_received(:chat) do |**kwargs|
          expect(kwargs[:max_completion_tokens]).to eq(2500)
        end
      end

      it "凡ミスがなければ【自分の凡ミス】セクションを出力しないこと" do
        described_class.get_advice(match_info)
        expect(OpenaiClient).to have_received(:chat) do |**kwargs|
          content = kwargs[:user_prompt]
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
          expect(OpenaiClient).to have_received(:chat) do |**kwargs|
            content = kwargs[:user_prompt]
            expect(content).to include("【自分の凡ミス（ミスが多い上位3技術。相手の好プレーとは別）】")
            expect(content).to include("サーブミス: 1件（凡ミス全体の100%）")
          end
        end

        it "システムプロンプトで原因を推測しない方針を伝えること" do
          described_class.get_advice(match_info)
          expect(OpenaiClient).to have_received(:chat) do |**kwargs|
            system = kwargs[:system]
            expect(system).to include("相手の好プレー")
            expect(system).to include("原因")
            expect(system).to include("推測してはいけません")
          end
        end
      end
    end
  end
end
