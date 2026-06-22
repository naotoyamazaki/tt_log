require 'rails_helper'

RSpec.describe ServeReceivePattern, type: :model do
  describe "バリデーション" do
    it "有効な属性で有効になること" do
      pattern = FactoryBot.build(:serve_receive_pattern)
      expect(pattern).to be_valid
    end

    it "originが無いと無効になること" do
      pattern = FactoryBot.build(:serve_receive_pattern, origin: nil)
      expect(pattern).to be_invalid
    end

    it "attack_styleが無いと無効になること" do
      pattern = FactoryBot.build(:serve_receive_pattern, attack_style: nil)
      expect(pattern).to be_invalid
    end

    it "decided_atが無いと無効になること" do
      pattern = FactoryBot.build(:serve_receive_pattern, decided_at: nil)
      expect(pattern).to be_invalid
    end

    it "game_numberが無いと無効になること" do
      pattern = FactoryBot.build(:serve_receive_pattern, game_number: nil)
      expect(pattern).to be_invalid
    end

    it "sequence_numberが無いと無効になること" do
      pattern = FactoryBot.build(:serve_receive_pattern, sequence_number: nil)
      expect(pattern).to be_invalid
    end

    it "wonがtrueで有効になること" do
      pattern = FactoryBot.build(:serve_receive_pattern, won: true)
      expect(pattern).to be_valid
    end

    it "wonがfalseで有効になること" do
      pattern = FactoryBot.build(:serve_receive_pattern, won: false)
      expect(pattern).to be_valid
    end

    it "wonがnilだと無効になること" do
      pattern = FactoryBot.build(:serve_receive_pattern, won: nil)
      expect(pattern).to be_invalid
    end
  end

  describe "enum" do
    it "originのenumが正しく定義されていること" do
      expect(ServeReceivePattern.origins).to eq({ 'serve' => 0, 'receive' => 1 })
    end

    it "serve_lengthのenumが正しく定義されていること" do
      expect(ServeReceivePattern.serve_lengths).to eq({ 'long' => 0, 'half_long' => 1, 'short' => 2 })
    end

    it "decided_atのenumが正しく定義されていること" do
      expect(ServeReceivePattern.decided_ats).to eq({ 'attack_ball' => 0, 'follow_ball' => 1, 'rally' => 2 })
    end
  end

  describe "定数" do
    it "SERVE_SPINSが正しく定義されていること" do
      expect(ServeReceivePattern::SERVE_SPINS).to include(:backspin, :topspin, :no_spin, :pro_sidespin, :anti_sidespin)
    end
  end

  describe ".allowed_attack_styles" do
    it "技術一覧を返すこと" do
      allowed = ServeReceivePattern.allowed_attack_styles
      expect(allowed).to include('fore_drive_vs_topspin', 'fore_drive_vs_backspin')
    end

    it "service_aceが含まれること" do
      expect(ServeReceivePattern.allowed_attack_styles).to include('service_ace')
    end

    it "receive_aceが含まれること" do
      expect(ServeReceivePattern.allowed_attack_styles).to include('receive_ace')
    end
  end

  describe "attack_style enum" do
    it "service_aceが22番として定義されていること" do
      expect(ServeReceivePattern.attack_styles['service_ace']).to eq(22)
    end

    it "receive_aceが23番として定義されていること" do
      expect(ServeReceivePattern.attack_styles['receive_ace']).to eq(23)
    end

    it "receive_missが24番として定義されていること" do
      expect(ServeReceivePattern.attack_styles['receive_miss']).to eq(24)
    end
  end

  describe ".allowed_attack_styles (receive_miss)" do
    it "receive_missが含まれること" do
      expect(ServeReceivePattern.allowed_attack_styles).to include('receive_miss')
    end
  end

  describe "serve_spinsの配列保存" do
    let(:match_info) { FactoryBot.create(:match_info) }

    it "複数の回転を配列で保存できること" do
      pattern = FactoryBot.create(:serve_receive_pattern, match_info: match_info, serve_spins: [0, 3])
      pattern.reload
      expect(pattern.serve_spins).to eq([0, 3])
    end
  end
end
