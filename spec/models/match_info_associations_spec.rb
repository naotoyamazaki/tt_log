require 'rails_helper'

RSpec.describe MatchInfo, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:player).class_name('Player') }
    it { should belong_to(:opponent).class_name('Player') }
    it { should have_many(:scores).dependent(:destroy) }
    it { should have_many(:games).dependent(:destroy) }
  end
end
