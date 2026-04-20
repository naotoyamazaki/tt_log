FactoryBot.define do
  factory :game do
    association :match_info
    game_number { 1 }
    player_score { 11 }
    opponent_score { 8 }
  end
end
