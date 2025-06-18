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
  end

  describe "POST /match_infos" do
    let(:params) do
      {
        match_info: attributes_for(:match_info).merge(
          player_name: "選手A",
          opponent_name: "選手B"
        )
      }
    end

    it "新規作成できること" do
      expect {
        post match_infos_path, params: params
      }.to change(MatchInfo, :count).by(1)
      expect(response).to redirect_to(MatchInfo.last)
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
      expect {
        delete match_info_path(match_info)
      }.to change(MatchInfo, :count).by(-1)
      expect(response).to redirect_to(match_infos_path)
    end
  end
end
