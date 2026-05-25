require 'rails_helper'

RSpec.describe RallyContextBuilder do
  let(:user) { create(:user) }
  let(:match_info) { create(:match_info, user: user) }
  let(:game) { create(:game, match_info: match_info, game_number: 1, first_server: :player) }

  def create_rally(seq_num, winner, batting_style, grp = game)
    create(:rally, match_info: match_info, game: grp, game_number: grp.game_number,
                   sequence_number: seq_num, winner: winner, batting_style: batting_style)
  end

  describe "#technique_efficiency_text" do
    before do
      create_rally(1, :player, :fore_drive_vs_topspin)
      create_rally(2, :player, :fore_drive_vs_topspin)
      create_rally(3, :player, :fore_drive_vs_topspin)
      create_rally(4, :opponent, :fore_drive_vs_topspin)
      create_rally(5, :player, :serve)
      create_rally(6, :opponent, :serve)
      create_rally(7, :opponent, :serve)
    end

    it "勝率降順で返すこと" do
      result = described_class.new(match_info).technique_efficiency_text
      lines = result.split("\n")
      expect(lines.first).to include("対上回転フォアドライブ")
      expect(lines.first).to include("75%")
      expect(lines.last).to include("サーブ")
    end

    it "得点と失点を含むこと" do
      result = described_class.new(match_info).technique_efficiency_text
      expect(result).to include("得点 3 / 失点 1")
    end
  end

  describe "#serve_situation_text" do
    context "サーブ権が設定されている場合" do
      before do
        # seq 1,2 → player serves (idx 0,1 → floor(0/2)%2=0, floor(1/2)%2=0)
        create_rally(1, :player, :serve)
        create_rally(2, :player, :serve)
        # seq 3,4 → opponent serves (idx 2,3 → floor(2/2)%2=1)
        create_rally(3, :opponent, :serve)
        create_rally(4, :opponent, :serve)
      end

      it "自分のサーブ時と相手のサーブ時の得点率を返すこと" do
        result = described_class.new(match_info).serve_situation_text
        expect(result).to include("自分のサーブ時")
        expect(result).to include("相手のサーブ時")
        expect(result).to include("得点率 100%")
      end
    end

    context "20本目以降のデュース時" do
      before do
        # seq 21 → idx 20, 20%2=0 → initial server (player) serves
        create_rally(21, :player, :serve)
        # seq 22 → idx 21, 21%2=1 → opponent serves
        create_rally(22, :opponent, :serve)
      end

      it "デュース時のサーブ権を正しく計算すること" do
        result = described_class.new(match_info).serve_situation_text
        expect(result).to include("自分のサーブ時")
        expect(result).to include("相手のサーブ時")
      end
    end
  end

  describe "#situation_stats_text" do
    before do
      # 序盤: 0-0 → close
      create_rally(1, :player, :serve)  # 1-0
      create_rally(2, :player, :serve)  # 2-0
      create_rally(3, :player, :serve)  # 3-0 → leading from here
      create_rally(4, :player, :serve)  # 4-0
      create_rally(5, :opponent, :serve) # 4-1
    end

    it "接戦とリード時の分類を含むこと" do
      result = described_class.new(match_info).situation_stats_text
      expect(result).to include("接戦（±2点差）")
      expect(result).to include("リード時（+3点以上）")
    end

    it "デュース判定が正しいこと" do
      # 10-10になる状況を作る
      game2 = create(:game, match_info: match_info, game_number: 2, first_server: :player)
      10.times { |i| create_rally(i + 1, :player, :serve, game2) }
      10.times { |i| create_rally(i + 11, :opponent, :serve, game2) }
      create_rally(21, :player, :serve, game2)

      result = described_class.new(match_info).situation_stats_text
      expect(result).to include("デュース（10-10以降）")
    end
  end

  describe "#momentum_text" do
    before do
      create_rally(1, :opponent, :serve)
      create_rally(2, :opponent, :serve)
      create_rally(3, :opponent, :serve)
      create_rally(4, :opponent, :serve)
      create_rally(5, :player, :fore_drive_vs_topspin)
      create_rally(6, :player, :fore_drive_vs_topspin)
    end

    it "最大連続失点を返すこと" do
      result = described_class.new(match_info).momentum_text
      expect(result).to include("最大連続失点: 4本")
    end

    it "立て直し技術を返すこと" do
      result = described_class.new(match_info).momentum_text
      expect(result).to include("対上回転フォアドライブ")
    end
  end

  describe "ralliesが空の場合" do
    it "technique_efficiency_textが例外を出さないこと" do
      expect { described_class.new(match_info).technique_efficiency_text }.not_to raise_error
    end

    it "serve_situation_textが例外を出さないこと" do
      expect { described_class.new(match_info).serve_situation_text }.not_to raise_error
    end

    it "situation_stats_textが例外を出さないこと" do
      expect { described_class.new(match_info).situation_stats_text }.not_to raise_error
    end

    it "momentum_textが例外を出さないこと" do
      expect { described_class.new(match_info).momentum_text }.not_to raise_error
    end

    it "momentum_textが連続失点0本を返すこと" do
      result = described_class.new(match_info).momentum_text
      expect(result).to include("最大連続失点: 0本")
    end
  end
end
