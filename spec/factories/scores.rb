FactoryBot.define do
  factory :score do
    match_info
    batting_style { :fore_drive }
    score { 5 }
    lost_score { 2 }
  end
end
