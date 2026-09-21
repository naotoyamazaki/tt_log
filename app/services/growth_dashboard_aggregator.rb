# 複数試合を横断して技術別の得点率推移を集計するサービス。
# RallyContextBuilder と同様に「対象データを受け取り集計結果の配列を返す」パターンを踏襲する。
class GrowthDashboardAggregator
  def initialize(match_infos:, batting_style:, period: :month)
    @match_infos = match_infos
    @batting_style = batting_style.to_s
    @period = period
  end

  # => [{ period_label: "2026-08", rate: 62, score: 10, lost_score: 6, match_count: 3 }, ...]
  def monthly_rate_series
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
    scores = infos.flat_map(&:scores).select { |score| score.batting_style.to_s == @batting_style }
    return nil if scores.empty?

    total_score = scores.sum(&:score)
    total_lost_score = scores.sum(&:lost_score)
    {
      period_label: period_label_for(period_start),
      rate: calculate_rate(total_score, total_lost_score),
      score: total_score,
      lost_score: total_lost_score,
      match_count: infos.size
    }
  end

  def period_label_for(period_start)
    period_start.strftime("%Y-%m")
  end

  def calculate_rate(score, lost_score)
    total = score + lost_score
    total.positive? ? (score.to_f / total * 100).round : 0
  end
end
