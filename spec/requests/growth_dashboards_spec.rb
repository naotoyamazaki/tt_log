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

        it "「得点率」ではなく得点構成比であることが伝わる表記になっていること" do
          get growth_dashboards_path
          expect(response.body).to include("得点構成比")
          expect(response.body).not_to include("得点率の推移")
        end
      end

      context "下書き（draft: true）の試合がある場合" do
        it "下書き試合単独では集計対象がなく空状態メッセージが表示されること" do
          draft_match_info = create(:match_info, user: user, draft: true, match_date: Date.new(2026, 8, 1))
          create(:score, match_info: draft_match_info, batting_style: :fore_drive_vs_topspin, score: 6, lost_score: 4)

          get growth_dashboards_path

          expect(response.body).to include("まだ表示できる試合データがありません")
          expect(response.body).not_to include("2026-08")
        end

        it "完了試合と同月に下書き試合が混在しても下書き分が集計に加算されないこと" do
          completed_match_info = create(:match_info, user: user, match_date: Date.new(2026, 8, 1))
          create(:score, match_info: completed_match_info, batting_style: :fore_drive_vs_topspin,
                         score: 6, lost_score: 4)
          create(:score, match_info: completed_match_info, batting_style: :fore_push, score: 4, lost_score: 0)
          draft_match_info = create(:match_info, user: user, draft: true, match_date: Date.new(2026, 8, 10))
          create(:score, match_info: draft_match_info, batting_style: :fore_drive_vs_topspin, score: 94, lost_score: 0)

          get growth_dashboards_path

          # 下書きを含めると share は (6+94)/(6+4+94)=96% になるが、除外されれば 6/(6+4)=60% のはず
          expect(response.body).to include("2026-08")
          expect(response.body).to include("[60]")
          expect(response.body).not_to include("[96]")
        end
      end

      context "期間別明細テーブル" do
        it "期間ごとの得点構成比・得点数・総得点数・試合数が表に表示されること" do
          match_info = create(:match_info, user: user, match_date: Date.new(2026, 8, 5))
          create(:score, match_info: match_info, batting_style: :fore_drive_vs_topspin, score: 6, lost_score: 4)
          create(:score, match_info: match_info, batting_style: :serve, score: 4, lost_score: 0)

          get growth_dashboards_path

          expect(response.body).to include("2026-08")
          expect(response.body).to include("60%")
          expect(response.body).to include("対象技術の得点数")
          expect(response.body).to include("総得点数")
          expect(response.body).to include("集計試合数")
        end

        it "試合データが0件の場合はテーブルが表示されないこと" do
          get growth_dashboards_path

          expect(response.body).not_to include("対象技術の得点数")
        end
      end

      context "技術選択機能" do
        let!(:match_info) { create(:match_info, user: user, match_date: Date.new(2026, 8, 1)) }

        before do
          create(:score, match_info: match_info, batting_style: :fore_push, score: 5, lost_score: 1)
        end

        it "batting_styleパラメータに応じて対象技術を切り替えて表示すること" do
          get growth_dashboards_path, params: { batting_style: "fore_push" }
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("フォアツッツキ")
        end

        it "不正なbatting_styleが渡された場合はデフォルト(fore_drive_vs_topspin)にフォールバックすること" do
          get growth_dashboards_path, params: { batting_style: "not_a_real_style" }
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("対上回転フォアドライブ")
        end

        it "receiveのような選択不可な値が渡された場合もデフォルトにフォールバックすること" do
          get growth_dashboards_path, params: { batting_style: "receive" }
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("対上回転フォアドライブ")
        end

        it "セレクトボックスに全ての選択可能な技術が選択肢として表示されること" do
          get growth_dashboards_path
          expect(response.body).to include("<select")
          expect(response.body).to include("フォアツッツキ")
          expect(response.body).not_to include(">レシーブ<")
        end
      end

      context "表示期間切り替え機能" do
        let!(:match_info) { create(:match_info, user: user, match_date: Date.new(2026, 8, 3)) }

        before do
          create(:score, match_info: match_info, batting_style: :fore_drive_vs_topspin, score: 6, lost_score: 4)
        end

        it "periodパラメータがweekの場合は週別で表示すること" do
          get growth_dashboards_path, params: { period: "week" }
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("週別")
        end

        it "periodパラメータがmonthの場合は月別で表示すること" do
          get growth_dashboards_path, params: { period: "month" }
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("月別")
          expect(response.body).to include("2026-08")
        end

        it "periodパラメータが未指定の場合は月別がデフォルトであること" do
          get growth_dashboards_path
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("月別")
        end

        it "不正なperiodが渡された場合は月別にフォールバックすること" do
          get growth_dashboards_path, params: { period: "not_a_real_period" }
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("月別")
        end
      end
    end
  end
end
