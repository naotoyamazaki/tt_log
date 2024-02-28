class MatchInfo < ApplicationRecord
  belongs_to :user
  belongs_to :player, class_name: "Player", foreign_key: "player_id"
  belongs_to :opponent, class_name: "Player", foreign_key: "opponent_id"
  attr_accessor :player_name, :opponent_name
  has_many :scores, dependent: :destroy
  accepts_nested_attributes_for :scores, update_only: true
  has_many :games

  def self.ransackable_attributes(auth_object = nil)
    ["match_name", "player_id", "opponent_id"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["player"]
  end

    # Ransackのカスタムスコープを定義
  def self.ransackable_scopes(auth_object = nil)
    [:opponent_player_name_cont]
  end

  def self.opponent_player_name_cont(query)
    joins(:opponent).where("players.player_name LIKE ?", "%#{query}%")
  end
end
