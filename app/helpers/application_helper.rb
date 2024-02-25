module ApplicationHelper
  def calculate_point_rate(scores)
    total_score = scores.sum(:score)
    total_lost_score = scores.sum(:lost_score)
    total = total_score + total_lost_score
    total > 0 ? (total_score.to_f / total * 100).round(2) : 0
  end
end
