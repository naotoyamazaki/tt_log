require 'rails_helper'

RSpec.describe GrowthDashboardAggregator do
  let(:user) { create(:user) }

  def match_info_with_score(match_date, batting_style, score, lost_score)
    match_info = create(:match_info, user: user, match_date: match_date)
    create(:score, match_info: match_info, batting_style: batting_style, score: score, lost_score: lost_score)
    match_info
  end

  describe "#monthly_rate_series" do
    it "月別にグループ化し得点率を計算すること" do
      match_info_with_score(Date.new(2026, 8, 5), :fore_drive_vs_topspin, 6, 4)
      match_info_with_score(Date.new(2026, 8, 20), :fore_drive_vs_topspin, 4, 2)
      match_info_with_score(Date.new(2026, 9, 3), :fore_drive_vs_topspin, 3, 7)

      match_infos = user.match_infos.includes(:scores)
      result = described_class.new(match_infos: match_infos, batting_style: "fore_drive_vs_topspin").monthly_rate_series

      expect(result).to eq(
        [
          { period_label: "2026-08", rate: 63, score: 10, lost_score: 6, match_count: 2 },
          { period_label: "2026-09", rate: 30, score: 3, lost_score: 7, match_count: 1 }
        ]
      )
    end

    it "対象技術以外のScoreは集計対象外にすること" do
      match_info_with_score(Date.new(2026, 8, 5), :serve, 10, 0)

      match_infos = user.match_infos.includes(:scores)
      result = described_class.new(match_infos: match_infos, batting_style: "fore_drive_vs_topspin").monthly_rate_series

      expect(result).to eq([])
    end

    it "得点も失点も0の場合はレートを0とすること（0除算対策）" do
      match_info_with_score(Date.new(2026, 8, 5), :fore_drive_vs_topspin, 0, 0)

      match_infos = user.match_infos.includes(:scores)
      result = described_class.new(match_infos: match_infos, batting_style: "fore_drive_vs_topspin").monthly_rate_series

      expect(result).to eq(
        [{ period_label: "2026-08", rate: 0, score: 0, lost_score: 0, match_count: 1 }]
      )
    end

    it "データがない月は結果から省くこと" do
      match_info_with_score(Date.new(2026, 8, 5), :fore_drive_vs_topspin, 5, 5)
      # 9月分のデータは作成しない

      match_infos = user.match_infos.includes(:scores)
      result = described_class.new(match_infos: match_infos, batting_style: "fore_drive_vs_topspin").monthly_rate_series

      expect(result.map { |entry| entry[:period_label] }).to eq(["2026-08"])
    end

    it "月の昇順で返すこと" do
      match_info_with_score(Date.new(2026, 9, 1), :fore_drive_vs_topspin, 1, 1)
      match_info_with_score(Date.new(2026, 6, 1), :fore_drive_vs_topspin, 1, 1)
      match_info_with_score(Date.new(2026, 8, 1), :fore_drive_vs_topspin, 1, 1)

      match_infos = user.match_infos.includes(:scores)
      result = described_class.new(match_infos: match_infos, batting_style: "fore_drive_vs_topspin").monthly_rate_series

      expect(result.map { |entry| entry[:period_label] }).to eq(["2026-06", "2026-08", "2026-09"])
    end
  end
end
