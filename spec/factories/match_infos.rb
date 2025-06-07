FactoryBot.define do
  factory :match_info do
    association :user
    association :player, factory: :player
    association :opponent, factory: :player
    match_date { Time.zone.today }
    match_name { "テストマッチ" }
    memo { "テストメモ" }
    player_name { "選手A" }
    opponent_name { "選手B" }
  end
end
