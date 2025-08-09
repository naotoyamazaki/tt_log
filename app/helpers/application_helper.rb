module ApplicationHelper
  include Pagy::Frontend

  def calculate_point_rate(scores)
    total_score = scores.sum(:score)
    total_lost_score = scores.sum(:lost_score)
    total = total_score + total_lost_score
    total.positive? ? (total_score.to_f / total * 100).round : 0
  end

  def calculate_batting_score_data(batting_scores)
    data = batting_scores.map do |score|
      total = score.score + score.lost_score
      rate = total.positive? ? (score.score.to_f / total * 100).round : 0
      { batting_style: score.batting_style, rate: rate }
    end

    data.sort_by { |entry| -entry[:rate] } # 得点率の降順
  end

  # 得点数と失点数データ整備（API送信用）
  def prepare_batting_score_data(batting_scores)
    batting_scores.map do |score|
      {
        batting_style: score.batting_style,
        score: score.score,
        lost_score: score.lost_score
      }
    end
  end
end
