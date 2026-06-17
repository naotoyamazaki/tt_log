FactoryBot.define do
  factory :serve_receive_pattern do
    association :match_info
    association :game
    game_number { 1 }
    sequence_number { 1 }
    origin { :serve }
    serve_length { :short }
    serve_spins { [0] }
    attack_style { :fore_drive_vs_backspin }
    decided_at { :attack_ball }
    won { true }
  end
end
