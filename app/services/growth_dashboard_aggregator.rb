# 複数試合を横断して技術別の「得点内訳における使用率（シェア）」推移を集計するサービス。
# RallyContextBuilder と同様に「対象データを受け取り集計結果の配列を返す」パターンを踏襲する。
#
# 注意: Score#score/#lost_score は「1ポイントを決定づけた技術」を勝敗で振り分けているだけであり、
# 「その技術を使った際の成功率」を測れるデータではない（rally_input_controller.js の記録仕様に起因する
# 構造的な制約）。そのため本サービスは成功率（得点率）ではなく、当月の自分の全得点（receiveを除く）に
# 対して対象技術が占める割合＝使用率（シェア）を算出する。
class GrowthDashboardAggregator
  def initialize(match_infos:, batting_style:, period: :month)
    @match_infos = match_infos
    @batting_style = batting_style.to_s
    @period = period
  end

  # => [{ period_label: "2026-08", share: 62, score: 10, total_score: 16, match_count: 3 }, ...]
  def monthly_usage_share_series
    entries = grouped_match_infos.filter_map { |period_start, infos| build_period_entry(period_start, infos) }
    entries.sort_by { |entry| entry[:period_label] }
  end

  private

  def grouped_match_infos
    @match_infos.group_by { |match_info| period_start_for(match_info) }
  end

  def period_start_for(match_info)
    case @period
    when :week
      match_info.match_date.beginning_of_week
    else
      match_info.match_date.beginning_of_month
    end
  end

  def build_period_entry(period_start, infos)
    all_scores = infos.flat_map(&:scores).reject { |score| score.batting_style.to_s == "receive" }
    total_score = all_scores.sum(&:score)
    return nil if total_score.zero?

    target_score = all_scores.select { |score| score.batting_style.to_s == @batting_style }.sum(&:score)
    {
      period_label: period_label_for(period_start),
      share: calculate_share(target_score, total_score),
      score: target_score,
      total_score: total_score,
      match_count: infos.size
    }
  end

  def period_label_for(period_start)
    period_start.strftime("%Y-%m")
  end

  def calculate_share(target_score, total_score)
    (target_score.to_f / total_score * 100).round
  end
end
