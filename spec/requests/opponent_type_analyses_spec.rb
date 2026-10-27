require 'rails_helper'

RSpec.describe "OpponentTypeAnalyses", type: :request do
  describe "GET /opponent_type_analysis" do
    context "未ログインの場合" do
      it "ログインしていない場合はリダイレクトされること" do
        get opponent_type_analysis_path
        expect(response).to have_http_status(:redirect)
      end
    end

    context "ログイン済みの場合" do
      let(:user) { create(:user) }
      let(:other_user) { create(:user) }

      before { login_as(user) }

      it "200を返すこと" do
        get opponent_type_analysis_path
        expect(response).to have_http_status(:ok)
      end

      context "試合データが0件の場合" do
        it "対戦成績・サーブレシーブ分析それぞれの空状態メッセージが表示されること" do
          get opponent_type_analysis_path

          expect(response.body).to include("まだこの戦型との対戦データがありません")
          expect(response.body).to include("この戦型のサーブ・レシーブ分析データがまだありません")
        end
      end

      context "デフォルト戦型の決定" do
        it "完了試合数が最多の戦型がデフォルトで選択されること" do
          create(:game, match_info: create(:match_info, user: user, opponent_playstyle: :cutman),
                        game_number: 1, player_score: 11, opponent_score: 5)
          2.times do
            match_info = create(:match_info, user: user, opponent_playstyle: :front_drive)
            create(:game, match_info: match_info, game_number: 1, player_score: 11, opponent_score: 5)
          end

          get opponent_type_analysis_path

          expect(response.body).to include('<option selected="selected" value="front_drive">前陣ドライブ型</option>')
        end

        it "戦型が設定された試合が0件の場合はfront_driveにフォールバックすること" do
          create(:match_info, user: user)

          get opponent_type_analysis_path

          expect(response.body).to include('<option selected="selected" value="front_drive">前陣ドライブ型</option>')
        end
      end

      context "不正パラメータのフォールバック" do
        it "不正な戦型が渡された場合はデフォルト戦型にフォールバックすること" do
          get opponent_type_analysis_path, params: { opponent_playstyle: "not_a_real_playstyle" }

          expect(response).to have_http_status(:ok)
          expect(response.body).to include('<option selected="selected" value="front_drive">前陣ドライブ型</option>')
        end
      end

      context "対戦成績サマリー" do
        let!(:match_info) { create(:match_info, user: user, opponent_playstyle: :cutman) }

        before do
          create(:game, match_info: match_info, game_number: 1, player_score: 11, opponent_score: 5)
          create(:game, match_info: match_info, game_number: 2, player_score: 11, opponent_score: 9)
        end

        it "選択戦型の試合数・勝敗・勝率が表示されること" do
          get opponent_type_analysis_path, params: { opponent_playstyle: "cutman" }

          expect(response.body).to include("この戦型との対戦成績")
          expect(response.body).to include("100%")
        end

        it "他ユーザーの試合が集計に混ざらないこと" do
          other_match_info = create(:match_info, user: other_user, opponent_playstyle: :cutman)
          create(:game, match_info: other_match_info, game_number: 1, player_score: 5, opponent_score: 11)
          create(:game, match_info: other_match_info, game_number: 2, player_score: 5, opponent_score: 11)

          get opponent_type_analysis_path, params: { opponent_playstyle: "cutman" }

          expect(response.body).to include("100%")
        end

        it "下書き（draft: true）の試合が集計から除外されること" do
          draft_match_info = create(:match_info, user: user, opponent_playstyle: :cutman, draft: true)
          create(:game, match_info: draft_match_info, game_number: 1, player_score: 5, opponent_score: 11)
          create(:game, match_info: draft_match_info, game_number: 2, player_score: 5, opponent_score: 11)

          get opponent_type_analysis_path, params: { opponent_playstyle: "cutman" }

          expect(response.body).to include("100%")
        end
      end

      context "サーブ・レシーブ決定率" do
        it "analysis_type: serve_receiveの試合のみ対象になること" do
          srp_match_info = create(:match_info, user: user, opponent_playstyle: :cutman, analysis_type: :serve_receive)
          game = create(:game, match_info: srp_match_info, game_number: 1)
          create(:serve_receive_pattern, match_info: srp_match_info, game: game, game_number: 1, sequence_number: 1,
                                         origin: :serve, serve_length: :short, serve_spins: [0],
                                         attack_style: :fore_drive_vs_backspin, decided_at: :attack_ball, won: true)

          technique_match_info = create(:match_info, user: user, opponent_playstyle: :cutman,
                                                     analysis_type: :technique)

          get opponent_type_analysis_path, params: { opponent_playstyle: "cutman" }

          expect(response.body).to include("サーブ長さ別得点率")
          expect(response.body).not_to include("この戦型のサーブ・レシーブ分析データがまだありません")
          expect(technique_match_info.analysis_type).to eq("technique")
        end

        it "対象データが無い場合は空状態メッセージが表示されること" do
          create(:match_info, user: user, opponent_playstyle: :cutman)

          get opponent_type_analysis_path, params: { opponent_playstyle: "cutman" }

          expect(response.body).to include("この戦型のサーブ・レシーブ分析データがまだありません")
        end
      end

      it "成長ダッシュボードへの導線リンクに選択戦型が引き継がれること" do
        get opponent_type_analysis_path, params: { opponent_playstyle: "cutman" }

        expect(response.body).to include(growth_dashboards_path(opponent_playstyle: "cutman"))
      end
    end
  end
end
