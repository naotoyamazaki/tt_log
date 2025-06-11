require 'rails_helper'

RSpec.describe User, type: :model do
  describe "アソシエーション" do
    it { should have_many(:match_infos).dependent(:restrict_with_error) }
  end
end
