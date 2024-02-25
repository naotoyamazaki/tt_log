class MatchInfo < ApplicationRecord
  belongs_to :user
  belongs_to :player, class_name: "Player", foreign_key: "player_id"
  belongs_to :opponent, class_name: "Player", foreign_key: "opponent_id"
  has_many :scores, dependent: :destroy
  accepts_nested_attributes_for :scores, update_only: true
  has_many :games
end
