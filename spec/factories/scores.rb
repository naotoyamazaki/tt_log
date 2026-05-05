FactoryBot.define do
  factory :score do
    match_info
    batting_style { :fore_drive_vs_topspin }
    score { 5 }
    lost_score { 2 }
  end
end
