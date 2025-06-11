require 'rails_helper'

RSpec.describe User, type: :model do
  describe "Sorcery認証" do
    let!(:user) { create(:user, password: "secure123", password_confirmation: "secure123") }

    it "正しいパスワードで認証できること" do
      authenticated_user = User.authenticate(user.email, "secure123")
      expect(authenticated_user).to eq(user)
    end

    it "間違ったパスワードでは認証されないこと" do
      authenticated_user = User.authenticate(user.email, "wrongpass")
      expect(authenticated_user).to be_nil
    end
  end
end
