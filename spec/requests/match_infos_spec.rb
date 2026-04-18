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
          "fore_drive" => { "score" => "2", "lost_score" => "1" }
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
        "fore_drive" => { "score" => "6", "lost_score" => "3" }
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
