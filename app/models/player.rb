class Player < ApplicationRecord
  has_many :match_infos_as_player, class_name: 'MatchInfo', inverse_of: :player, dependent: :restrict_with_error
  has_many :match_infos_as_opponent, class_name: 'MatchInfo', inverse_of: :opponent, dependent: :restrict_with_error

  def self.ransackable_attributes(_auth_object = nil)
    ["player_name"]
  end
end
