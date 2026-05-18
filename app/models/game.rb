class Game < ApplicationRecord
  has_many :scores, dependent: :destroy
  has_many :rallies, dependent: :destroy
  belongs_to :match_info
  accepts_nested_attributes_for :scores

  enum :first_server, { player: 0, opponent: 1 }

  def recalculate_scores
    update(
      player_score: scores.sum(:score),
      opponent_score: scores.sum(:lost_score)
    )
  end
end
