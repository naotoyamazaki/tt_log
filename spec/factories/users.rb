FactoryBot.define do
  factory :user do
    name { "テスト太郎" }
    email { "test@example.com" }
    password { "password" }
    password_confirmation { "password" }
  end
end
