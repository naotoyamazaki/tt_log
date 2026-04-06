module ApplicationHelper
  include Pagy::Frontend

  def abbreviate_batting_style(name)
    name.gsub('フォア', 'F').gsub('バック', 'B')
  end

  def calculate_batting_score_data(batting_scores)
    data = batting_scores.map do |score|
      total = score.score + score.lost_score
      rate = total.positive? ? (score.score.to_f / total * 100).round : 0
      { batting_style: score.batting_style, rate: rate, score: score.score, lost_score: score.lost_score }
    end

    data.sort_by { |entry| -entry[:rate] }
  end
end
