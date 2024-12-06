module ApplicationHelper
  def calculate_point_rate(scores)
    total_score = scores.sum(:score)
    total_lost_score = scores.sum(:lost_score)
    total = total_score + total_lost_score
    total > 0 ? (total_score.to_f / total * 100).round(2) : 0
  end

  def calculate_batting_score_data(batting_scores)
    batting_scores.map do |score|
      total = score.score + score.lost_score
      rate = total > 0 ? (score.score.to_f / total * 100).round(2) : 0
      { batting_style: score.batting_style, rate: rate }
    end.sort_by { |data| -data[:rate] } # 得点率の降順
  end
end
