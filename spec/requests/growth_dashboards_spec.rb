require 'rails_helper'

RSpec.describe "GrowthDashboards", type: :request do
  describe "GET /growth_dashboards" do
    context "未ログインの場合" do
      it "ログインしていない場合はリダイレクトされること" do
        get growth_dashboards_path
        expect(response).to have_http_status(:redirect)
      end
    end

    context "ログイン済みの場合" do
      let(:user) { create(:user) }

      before { login_as(user) }

      it "200を返すこと" do
        get growth_dashboards_path
        expect(response).to have_http_status(:ok)
      end

      context "試合データが0件の場合" do
        it "空状態メッセージを表示すること" do
          get growth_dashboards_path
          expect(response.body).to include("まだ表示できる試合データがありません")
        end
      end

      context "対象技術のスコアを持つ試合データがある場合" do
        let!(:match_info) { create(:match_info, user: user, match_date: Date.new(2026, 8, 1)) }

        before do
          create(:score, match_info: match_info, batting_style: :fore_drive_vs_topspin, score: 6, lost_score: 4)
        end

        it "グラフ用データがviewに渡ること" do
          get growth_dashboards_path
          expect(response.body).to include("2026-08")
          expect(response.body).to include("growth-chart")
        end
      end
    end
  end
end
