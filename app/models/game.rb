class Game < ApplicationRecord
  has_many :scores, dependent: :destroy
  belongs_to :match_info
  accepts_nested_attributes_for :scores

  def recalculate_scores
    update(
      player_score: scores.sum(:score),
      opponent_score: scores.sum(:lost_score)
    )
  end
end
