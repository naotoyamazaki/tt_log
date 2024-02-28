class MatchInfo < ApplicationRecord
  belongs_to :user
  belongs_to :player, class_name: "Player", foreign_key: "player_id"
  belongs_to :opponent, class_name: "Player", foreign_key: "opponent_id"
  attr_accessor :player_name, :opponent_name
  has_many :scores, dependent: :destroy
  accepts_nested_attributes_for :scores, update_only: true
  has_many :games
end
