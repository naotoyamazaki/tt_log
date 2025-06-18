require 'rails_helper'

RSpec.describe User, type: :model do
  describe "バリデーション" do
    it "有効なユーザーは有効であること" do
      expect(build(:user)).to be_valid
    end

    it "nameがないと無効になること" do
      user = build(:user, name: nil)
      expect(user).to be_invalid
      expect(user.errors[:name]).to include("を入力してください")
    end

    it "emailがないと無効になること" do
      user = build(:user, email: nil)
      expect(user).to be_invalid
    end

    it "同じemailは登録できないこと" do
      create(:user, email: "test@example.com")
      user = build(:user, email: "test@example.com")
      expect(user).to be_invalid
    end

    it "passwordが短すぎると無効になること" do
      user = build(:user, password: "a", password_confirmation: "a")
      expect(user).to be_invalid
    end

    it "passwordとpassword_confirmationが一致しないと無効になること" do
      user = build(:user, password: "password", password_confirmation: "different")
      expect(user).to be_invalid
    end

    it "reset_password_tokenが重複すると無効になること" do
      create(:user, reset_password_token: "token123")
      user = build(:user, reset_password_token: "token123")
      expect(user).to be_invalid
    end
  end
end
