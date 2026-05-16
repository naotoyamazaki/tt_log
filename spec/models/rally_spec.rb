require 'rails_helper'

RSpec.describe Rally, type: :model do
  describe 'バリデーション' do
    let(:rally) { build(:rally) }

    it '有効なファクトリが存在する' do
      expect(rally).to be_valid
    end

    it 'winner が nil の場合は無効' do
      rally.winner = nil
      expect(rally).not_to be_valid
      expect(rally.errors[:winner]).to be_present
    end

    it 'batting_style が nil の場合は無効' do
      rally.batting_style = nil
      expect(rally).not_to be_valid
      expect(rally.errors[:batting_style]).to be_present
    end

    it 'game_number が nil の場合は無効' do
      rally.game_number = nil
      expect(rally).not_to be_valid
      expect(rally.errors[:game_number]).to be_present
    end

    it 'sequence_number が nil の場合は無効' do
      rally.sequence_number = nil
      expect(rally).not_to be_valid
      expect(rally.errors[:sequence_number]).to be_present
    end
  end

  describe 'アソシエーション' do
    it 'match_info に belongs_to している' do
      expect(Rally.reflect_on_association(:match_info).macro).to eq(:belongs_to)
    end

    it 'game に belongs_to している（optional）' do
      assoc = Rally.reflect_on_association(:game)
      expect(assoc.macro).to eq(:belongs_to)
      expect(assoc.options[:optional]).to be_truthy
    end

    it 'game なしでも有効' do
      rally = build(:rally, game: nil)
      # game_id は nil でも valid（optional: true）
      rally.valid?
      expect(rally.errors[:game]).to be_empty
    end
  end

  describe 'enum: winner' do
    it 'player が 0 に対応する' do
      rally = build(:rally, winner: :player)
      expect(rally.winner).to eq('player')
      expect(Rally.winners[:player]).to eq(0)
    end

    it 'opponent が 1 に対応する' do
      rally = build(:rally, winner: :opponent)
      expect(rally.winner).to eq('opponent')
      expect(Rally.winners[:opponent]).to eq(1)
    end
  end

  describe 'enum: batting_style' do
    it 'serve が 0 に対応する' do
      expect(Rally.batting_styles[:serve]).to eq(0)
    end

    it 'fore_drive_vs_topspin が 15 に対応する' do
      expect(Rally.batting_styles[:fore_drive_vs_topspin]).to eq(15)
    end

    it 'back_drive_vs_topspin が 16 に対応する' do
      expect(Rally.batting_styles[:back_drive_vs_topspin]).to eq(16)
    end

    it 'fore_smash が 19 に対応する' do
      expect(Rally.batting_styles[:fore_smash]).to eq(19)
    end

    it 'net_or_edge が 21 に対応する' do
      expect(Rally.batting_styles[:net_or_edge]).to eq(21)
    end

    it 'chiquita が 10 に対応する' do
      expect(Rally.batting_styles[:chiquita]).to eq(10)
    end
  end
end
