class Player < ApplicationRecord
  has_many :match_infos_as_player, class_name: 'MatchInfo', foreign_key: 'player_id'
  has_many :match_infos_as_opponent, class_name: 'MatchInfo', foreign_key: 'opponent_id'

  def self.ransackable_attributes(auth_object = nil)
    ["player_name"]
  end

end
