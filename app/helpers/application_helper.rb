module ApplicationHelper
  include Pagy::Frontend

  def calculate_batting_score_data(batting_scores)
    data = batting_scores.map do |score|
      total = score.score + score.lost_score
      rate = total.positive? ? (score.score.to_f / total * 100).round : 0
      { batting_style: score.batting_style, rate: rate }
    end

    data.sort_by { |entry| -entry[:rate] }
  end

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
