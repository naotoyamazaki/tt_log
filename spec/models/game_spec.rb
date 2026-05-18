require 'rails_helper'

RSpec.describe Game, type: :model do
  describe 'enums' do
    it { is_expected.to define_enum_for(:first_server).with_values(player: 0, opponent: 1) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:match_info) }
    it { is_expected.to have_many(:scores).dependent(:destroy) }
    it { is_expected.to have_many(:rallies).dependent(:destroy) }
  end
end
