module ApplicationHelper
  include Pagy::Frontend

  def abbreviate_batting_style(name)
    name.gsub('フォア', 'F').gsub('バック', 'B')
  end

  def calculate_batting_score_data(batting_scores)
    aggregated = batting_scores.group_by(&:batting_style).map do |batting_style, scores|
      build_aggregated_score_data(batting_style, scores)
    end
    aggregated.sort_by { |entry| -entry[:rate] }
  end

  private

  def build_aggregated_score_data(batting_style, scores)
    total_score = scores.sum(&:score)
    total_lost = scores.sum(&:lost_score)
    total = total_score + total_lost
    rate = total.positive? ? (total_score.to_f / total * 100).round : 0
    { batting_style: batting_style, rate: rate, score: total_score, lost_score: total_lost }
  end
end
