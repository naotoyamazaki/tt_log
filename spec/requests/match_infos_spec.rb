require 'rails_helper'

RSpec.describe "MatchInfos", type: :request do
  let(:user) { create(:user) }

  before do
    login_as(user)
  end

  describe "GET /match_infos" do
    it "一覧ページにアクセスできること" do
      get match_infos_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /match_infos/:id" do
    let(:match_info) { create(:match_info, user: user) }

    it "詳細ページにアクセスできること" do
      get match_info_path(match_info)
      expect(response).to have_http_status(:ok)
    end

    context "ゲームデータがある場合" do
      let!(:game) { create(:game, match_info: match_info, game_number: 1, player_score: 11, opponent_score: 8) }

      before do
        allow(ChatgptService).to receive(:get_advice).and_return("テストアドバイス")
      end

      it "詳細ページにゲームスコアが含まれること" do
        get match_info_path(match_info)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("11-8")
      end

      it "ゲーム別スコアセクションが表示されること" do
        get match_info_path(match_info)
        expect(response.body).to include("ゲーム別スコア")
      end
    end

    context "ゲームデータがない場合" do
      it "ゲーム別スコアセクションが表示されないこと" do
        get match_info_path(match_info)
        expect(response.body).not_to include("game-score-summary")
      end
    end
  end

  describe "GET /match_infos/new" do
    it "新規作成ページにアクセスできること" do
      get new_match_info_path
      expect(response).to have_http_status(:ok)
    end

    context "draft_id が指定されている場合" do
      let(:draft) { create(:match_info, user: user) }

      it "下書き試合の情報を引き継いだフォームが表示される" do
        get new_match_info_path(draft_id: draft.id)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST /match_infos" do
    let(:params) do
      {
        match_info: attributes_for(:match_info).merge(
          player_name: "選手A",
          opponent_name: "選手B"
        ),
        game_scores: {
          "serve" => { "score" => "3", "lost_score" => "1" },
          "fore_drive_vs_topspin" => { "score" => "2", "lost_score" => "1" }
        }
      }
    end

    it "新規作成できること" do
      expect do
        post match_infos_path, params: params
      end.to change(MatchInfo, :count).by(1)
      expect(response).to redirect_to(MatchInfo.last)
    end

    it "ゲームと得点データが保存されること" do
      post match_infos_path, params: params
      match_info = MatchInfo.last
      expect(match_info.games.count).to eq(1)
      expect(match_info.games.first.player_score).to eq(5)
      expect(match_info.games.first.opponent_score).to eq(2)
      expect(match_info.scores.count).to eq(2)
    end
  end

  describe "POST /match_infos/end_game" do
    let(:game_scores) do
      {
        "serve" => { "score" => "5", "lost_score" => "2" },
        "fore_drive_vs_topspin" => { "score" => "6", "lost_score" => "3" }
      }
    end
    let(:match_info_params) do
      attributes_for(:match_info).merge(player_name: "選手A", opponent_name: "選手B")
    end

    context "下書きなし（1ゲーム目終了）" do
      it "MatchInfoと最初のゲームが作成されること" do
        expect do
          post end_game_match_infos_path, params: {
            match_info: match_info_params,
            game_scores: game_scores
          }
        end.to change(MatchInfo, :count).by(1).and change(Game, :count).by(1)

        draft = MatchInfo.last
        expect(draft.games.first.game_number).to eq(1)
        expect(draft.games.first.player_score).to eq(11)
        expect(draft.games.first.opponent_score).to eq(5)
        expect(response).to redirect_to(new_match_info_path(draft_id: draft.id))
      end
    end

    context "下書きあり（2ゲーム目以降）" do
      let!(:draft) { create(:match_info, user: user) }

      it "既存MatchInfoに新しいゲームが追加されること" do
        expect do
          post end_game_match_infos_path, params: {
            draft_id: draft.id,
            match_info: match_info_params,
            game_scores: game_scores
          }
        end.to change(Game, :count).by(1)

        expect(draft.games.count).to eq(1)
        expect(draft.games.first.game_number).to eq(1)
        expect(response).to redirect_to(new_match_info_path(draft_id: draft.id))
      end
    end
  end

  describe "DELETE /match_infos/undo_game" do
    context "下書きに1ゲームある場合" do
      let!(:draft) { create(:match_info, user: user, draft: true) }
      let!(:game) { create(:game, match_info: draft, game_number: 1, player_score: 11, opponent_score: 8) }

      it "ゲームのみ削除されてMatchInfoは残り draft のフォームへリダイレクトする" do
        expect do
          delete undo_game_match_infos_path, params: { draft_id: draft.id }
        end.to change(Game, :count).by(-1).and change(MatchInfo, :count).by(0)
        expect(response).to redirect_to(new_match_info_path(draft_id: draft.id))
      end
    end

    context "下書きに2ゲームある場合" do
      let!(:draft) { create(:match_info, user: user, draft: true) }
      let!(:game1) { create(:game, match_info: draft, game_number: 1, player_score: 11, opponent_score: 8) }
      let!(:game2) { create(:game, match_info: draft, game_number: 2, player_score: 9, opponent_score: 11) }

      it "最後のゲームのみ削除されて draft のフォームへリダイレクトする" do
        expect do
          delete undo_game_match_infos_path, params: { draft_id: draft.id }
        end.to change(Game, :count).by(-1).and change(MatchInfo, :count).by(0)
        expect(response).to redirect_to(new_match_info_path(draft_id: draft.id))
        expect(draft.reload.games.count).to eq(1)
      end
    end

    context "draft_id が存在しない場合" do
      it "新規フォームへリダイレクトする" do
        delete undo_game_match_infos_path, params: { draft_id: 999_999 }
        expect(response).to redirect_to(new_match_info_path)
      end
    end
  end

  describe "POST /match_infos/end_game (draft フラグ)" do
    let(:game_scores) do
      {
        "serve" => { "score" => "5", "lost_score" => "2" }
      }
    end
    let(:match_info_params) do
      attributes_for(:match_info).merge(player_name: "選手A", opponent_name: "選手B")
    end

    it "end_game 後に draft が true になること" do
      post end_game_match_infos_path, params: {
        match_info: match_info_params,
        game_scores: game_scores
      }
      expect(MatchInfo.last.draft).to be true
    end
  end

  describe "POST /match_infos (draft フラグ)" do
    let(:params) do
      {
        match_info: attributes_for(:match_info).merge(
          player_name: "選手A",
          opponent_name: "選手B"
        ),
        game_scores: {
          "serve" => { "score" => "3", "lost_score" => "1" }
        }
      }
    end

    it "create 後に draft が false になること" do
      post match_infos_path, params: params
      expect(MatchInfo.last.draft).to be false
    end
  end

  describe "PATCH /match_infos/:id" do
    let(:match_info) { create(:match_info, user: user) }

    it "更新できること" do
      patch match_info_path(match_info), params: {
        match_info: { match_name: "更新後の試合名", player_name: "選手A", opponent_name: "選手B" }
      }
      expect(response).to redirect_to(match_info_path(match_info))
      expect(match_info.reload.match_name).to eq("更新後の試合名")
    end
  end

  describe "DELETE /match_infos/:id" do
    let!(:match_info) { create(:match_info, user: user) }

    it "削除できること" do
      expect do
        delete match_info_path(match_info)
      end.to change(MatchInfo, :count).by(-1)
      expect(response).to redirect_to(match_infos_path)
    end
  end
end
