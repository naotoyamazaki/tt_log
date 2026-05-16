FactoryBot.define do
  factory :rally do
    association :match_info
    association :game
    game_number { 1 }
    sequence_number { 1 }
    winner { :player }
    batting_style { :serve }
  end
end
