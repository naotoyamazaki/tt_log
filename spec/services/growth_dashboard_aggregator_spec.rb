require 'rails_helper'

RSpec.describe GrowthDashboardAggregator do
  let(:user) { create(:user) }

  def match_info_with_scores(match_date, scores)
    match_info = create(:match_info, user: user, match_date: match_date)
    scores.each do |batting_style, score, lost_score|
      create(:score, match_info: match_info, batting_style: batting_style, score: score, lost_score: lost_score)
    end
    match_info
  end

  describe "#monthly_usage_share_series" do
    it "月別にグループ化し得点内訳における使用率を計算すること" do
      match_info_with_scores(Date.new(2026, 8, 5), [[:fore_drive_vs_topspin, 6, 4], [:serve, 4, 0]])
      match_info_with_scores(Date.new(2026, 8, 20), [[:fore_drive_vs_topspin, 4, 2]])
      match_info_with_scores(Date.new(2026, 9, 3), [[:fore_drive_vs_topspin, 3, 7], [:serve, 7, 0]])

      match_infos = user.match_infos.includes(:scores)
      result = described_class.new(
        match_infos: match_infos, batting_style: "fore_drive_vs_topspin"
      ).monthly_usage_share_series

      # 8月: fore_drive(6+4=10) / total(6+4+4=14) = 71%
      # 9月: fore_drive(3) / total(3+7=10) = 30%
      expect(result).to eq(
        [
          { period_label: "2026-08", share: 71, score: 10, total_score: 14, match_count: 2 },
          { period_label: "2026-09", share: 30, score: 3, total_score: 10, match_count: 1 }
        ]
      )
    end

    it "対象技術以外のScoreは分子には含まれないが分母(total_score)には含まれること" do
      match_info_with_scores(Date.new(2026, 8, 5), [[:serve, 10, 0]])

      match_infos = user.match_infos.includes(:scores)
      result = described_class.new(
        match_infos: match_infos, batting_style: "fore_drive_vs_topspin"
      ).monthly_usage_share_series

      expect(result).to eq(
        [{ period_label: "2026-08", share: 0, score: 0, total_score: 10, match_count: 1 }]
      )
    end

    it "receiveのScoreは合計(total_score)から除外すること" do
      match_info_with_scores(Date.new(2026, 8, 5), [[:fore_drive_vs_topspin, 5, 0], [:receive, 100, 0]])

      match_infos = user.match_infos.includes(:scores)
      result = described_class.new(
        match_infos: match_infos, batting_style: "fore_drive_vs_topspin"
      ).monthly_usage_share_series

      expect(result).to eq(
        [{ period_label: "2026-08", share: 100, score: 5, total_score: 5, match_count: 1 }]
      )
    end

    it "全得点合計が0の月は結果から省くこと（0除算対策）" do
      match_info_with_scores(Date.new(2026, 8, 5), [[:fore_drive_vs_topspin, 0, 0]])

      match_infos = user.match_infos.includes(:scores)
      result = described_class.new(
        match_infos: match_infos, batting_style: "fore_drive_vs_topspin"
      ).monthly_usage_share_series

      expect(result).to eq([])
    end

    it "データがない月は結果から省くこと" do
      match_info_with_scores(Date.new(2026, 8, 5), [[:fore_drive_vs_topspin, 5, 5]])
      # 9月分のデータは作成しない

      match_infos = user.match_infos.includes(:scores)
      result = described_class.new(
        match_infos: match_infos, batting_style: "fore_drive_vs_topspin"
      ).monthly_usage_share_series

      expect(result.map { |entry| entry[:period_label] }).to eq(["2026-08"])
    end

    it "月の昇順で返すこと" do
      match_info_with_scores(Date.new(2026, 9, 1), [[:fore_drive_vs_topspin, 1, 1]])
      match_info_with_scores(Date.new(2026, 6, 1), [[:fore_drive_vs_topspin, 1, 1]])
      match_info_with_scores(Date.new(2026, 8, 1), [[:fore_drive_vs_topspin, 1, 1]])

      match_infos = user.match_infos.includes(:scores)
      result = described_class.new(
        match_infos: match_infos, batting_style: "fore_drive_vs_topspin"
      ).monthly_usage_share_series

      expect(result.map { |entry| entry[:period_label] }).to eq(["2026-06", "2026-08", "2026-09"])
    end

    # 回帰テスト: 旧「得点率」定義（score/(score+lost_score)）では、対象技術で相手が多く得点し
    # lost_scoreが大きくても、自分のlost_scoreが記録されにくいデータ仕様のせいで100%近くに張り付いて
    # しまっていた。使用率（シェア）はlost_scoreを一切使わないため、この問題が再発しないことを検証する。
    it "対象技術のlost_scoreが大きくても使用率が100%固定にならず正しく計算されること" do
      match_info_with_scores(
        Date.new(2026, 8, 5),
        [
          [:fore_drive_vs_topspin, 2, 20], # 相手がフォアドライブで20点決めている想定（lost_scoreが多い）
          [:serve, 8, 0],
          [:back_drive_vs_topspin, 10, 0]
        ]
      )

      match_infos = user.match_infos.includes(:scores)
      result = described_class.new(
        match_infos: match_infos, batting_style: "fore_drive_vs_topspin"
      ).monthly_usage_share_series

      # total_score = 2 + 8 + 10 = 20, target_score = 2 → share = 10%
      # lost_scoreの大きさ(20)は使用率の計算に一切影響しない
      expect(result).to eq(
        [{ period_label: "2026-08", share: 10, score: 2, total_score: 20, match_count: 1 }]
      )
      expect(result.first[:share]).not_to eq(100)
    end
  end
end
