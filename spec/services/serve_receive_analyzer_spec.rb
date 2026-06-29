require 'rails_helper'

RSpec.describe ServeReceiveAnalyzer do
  let(:user) { create(:user) }
  let(:match_info) { create(:match_info, user: user, analysis_type: :serve_receive) }
  let(:game) { create(:game, match_info: match_info, game_number: 1) }

  def create_serve_pattern(attrs = {})
    defaults = {
      match_info: match_info,
      game: game,
      game_number: 1,
      sequence_number: ServeReceivePattern.count + 1,
      origin: :serve,
      serve_length: :short,
      serve_spins: [0],
      attack_style: :fore_drive_vs_backspin,
      decided_at: :attack_ball,
      won: true
    }
    create(:serve_receive_pattern, defaults.merge(attrs))
  end

  def create_receive_pattern(attrs = {})
    defaults = {
      match_info: match_info,
      game: game,
      game_number: 1,
      sequence_number: ServeReceivePattern.count + 1,
      origin: :receive,
      receive_style: ServeReceivePattern::RECEIVE_STYLE_VALUES[:chiquita],
      attack_style: :fore_drive_vs_backspin,
      decided_at: :attack_ball,
      won: true
    }
    create(:serve_receive_pattern, defaults.merge(attrs))
  end

  describe '#serve_length_stats' do
    context 'ショートサーブで3得点2失点のデータがある場合' do
      before do
        3.times { create_serve_pattern(serve_length: :short, won: true) }
        2.times { create_serve_pattern(serve_length: :short, won: false) }
      end

      it 'rate: 60, label: "ショート" を返すこと' do
        analyzer = described_class.new(match_info)
        result = analyzer.serve_length_stats
        expect(result).not_to be_empty
        short_stat = result.find { |s| s[:label] == 'ショート' }
        expect(short_stat).not_to be_nil
        expect(short_stat[:score]).to eq(3)
        expect(short_stat[:lost_score]).to eq(2)
        expect(short_stat[:rate]).to eq(60)
      end
    end

    context 'データなしの場合' do
      it '空配列を返すこと' do
        analyzer = described_class.new(match_info)
        expect(analyzer.serve_length_stats).to eq([])
      end
    end
  end

  describe '#serve_pattern_stats' do
    context '同一組み合わせを複数件入力した場合' do
      before do
        3.times do
          create_serve_pattern(serve_length: :short, serve_spins: [0], attack_style: :fore_drive_vs_backspin, won: true)
        end
        create_serve_pattern(serve_length: :short, serve_spins: [0], attack_style: :fore_drive_vs_backspin, won: false)
      end

      it 'まとめて集計されること' do
        analyzer = described_class.new(match_info)
        result = analyzer.serve_pattern_stats
        expect(result.length).to eq(1)
        expect(result.first[:score]).to eq(3)
        expect(result.first[:lost_score]).to eq(1)
      end

      it 'label フォーマットが正しいこと' do
        analyzer = described_class.new(match_info)
        result = analyzer.serve_pattern_stats
        expect(result.first[:label]).to include('ショート')
        expect(result.first[:label]).to include('下回転')
        expect(result.first[:label]).to include('→')
      end
    end
  end

  describe '#receive_direct_stats' do
    context 'レシーブエース・ミスのデータが存在する場合' do
      before do
        chiquita_val = ServeReceivePattern::RECEIVE_STYLE_VALUES[:chiquita]
        2.times { create_receive_pattern(receive_style: chiquita_val, attack_style: :receive_ace, won: true) }
        create_receive_pattern(receive_style: chiquita_val, attack_style: :receive_miss, won: false)
      end

      it 'レシーブ技術別の直接決着率を返すこと' do
        analyzer = described_class.new(match_info)
        result = analyzer.receive_direct_stats
        expect(result).not_to be_empty
        chiquita_stat = result.find { |s| s[:label].include?('チキータ') }
        expect(chiquita_stat).not_to be_nil
        expect(chiquita_stat[:score]).to eq(2)
        expect(chiquita_stat[:lost_score]).to eq(1)
        expect(chiquita_stat[:rate]).to eq(67)
      end
    end

    context 'レシーブエース・ミス以外のパターンしかない場合' do
      before do
        chiquita_val = ServeReceivePattern::RECEIVE_STYLE_VALUES[:chiquita]
        create_receive_pattern(receive_style: chiquita_val, attack_style: :fore_drive_vs_backspin, won: true)
      end

      it '空を返すこと' do
        expect(described_class.new(match_info).receive_direct_stats).to be_empty
      end
    end
  end

  describe '#receive_pattern_stats' do
    context '組み合わせ別に集計される場合' do
      before do
        chiquita_val = ServeReceivePattern::RECEIVE_STYLE_VALUES[:chiquita]
        fore_push_val = ServeReceivePattern::RECEIVE_STYLE_VALUES[:fore_push]
        3.times do
          create_receive_pattern(receive_style: chiquita_val, attack_style: :fore_drive_vs_backspin, won: true)
        end
        create_receive_pattern(receive_style: fore_push_val, attack_style: :back_push, won: true)
      end

      it '組み合わせ別に集計されること' do
        analyzer = described_class.new(match_info)
        result = analyzer.receive_pattern_stats
        expect(result.length).to eq(2)
      end

      it '得点数の降順でソートされること' do
        analyzer = described_class.new(match_info)
        result = analyzer.receive_pattern_stats
        scores = result.map { |s| s[:score] }
        expect(scores).to eq(scores.sort.reverse)
      end
    end
  end

  describe '#decided_at_distribution' do
    context '通常パターン（サービスエース・レシーブエースなし）の場合' do
      before do
        2.times { create_serve_pattern(decided_at: :attack_ball, won: true) }
        create_serve_pattern(decided_at: :follow_ball, won: false)
        2.times { create_receive_pattern(decided_at: :rally, won: true) }
      end

      it 'サーブ起点のラベルが3球目・5球目・7球目以降になること' do
        analyzer = described_class.new(match_info)
        dist = analyzer.decided_at_distribution
        serve = dist[:serve]
        expect(serve.find { |d| d[:label] == '3球目' }[:score]).to eq(2)
        expect(serve.find { |d| d[:label] == '5球目' }[:lost_score]).to eq(1)
        expect(serve.find { |d| d[:label] == '7球目以降' }[:score]).to eq(0)
      end

      it 'serve / receive が分離されること' do
        analyzer = described_class.new(match_info)
        dist = analyzer.decided_at_distribution
        serve_dist = dist[:serve]
        receive_dist = dist[:receive]

        expect(serve_dist.find { |d| d[:label] == '3球目' }[:score]).to eq(2)
        expect(receive_dist.find { |d| d[:label] == '8球目以降' }[:score]).to eq(2)
      end

      it '得点率が計算されること' do
        analyzer = described_class.new(match_info)
        dist = analyzer.decided_at_distribution
        attack_ball = dist[:serve].find { |d| d[:label] == '3球目' }
        expect(attack_ball[:rate]).to eq(100)
      end
    end

    context 'サービスエースがある場合' do
      before do
        create_serve_pattern(attack_style: :service_ace, decided_at: :attack_ball, won: true)
        create_serve_pattern(decided_at: :attack_ball, won: true)
      end

      it '1球目が独立した行として集計されること' do
        analyzer = described_class.new(match_info)
        dist = analyzer.decided_at_distribution
        first_ball = dist[:serve].find { |d| d[:label] == '1球目' }
        third_ball = dist[:serve].find { |d| d[:label] == '3球目' }
        expect(first_ball[:score]).to eq(1)
        expect(third_ball[:score]).to eq(1)
      end
    end

    context 'レシーブエース・ミスがある場合' do
      before do
        chiquita_val = ServeReceivePattern::RECEIVE_STYLE_VALUES[:chiquita]
        create_receive_pattern(receive_style: chiquita_val, attack_style: :receive_ace,
                               decided_at: :attack_ball, won: true)
        create_receive_pattern(receive_style: chiquita_val, attack_style: :receive_miss,
                               decided_at: :attack_ball, won: false)
        create_receive_pattern(decided_at: :attack_ball, won: true)
      end

      it '2球目が独立した行として集計されること' do
        analyzer = described_class.new(match_info)
        dist = analyzer.decided_at_distribution
        second_ball = dist[:receive].find { |d| d[:label] == '2球目' }
        fourth_ball = dist[:receive].find { |d| d[:label] == '4球目' }
        expect(second_ball[:score]).to eq(1)
        expect(second_ball[:lost_score]).to eq(1)
        expect(fourth_ball[:score]).to eq(1)
      end
    end
  end

  describe '#empty?' do
    context 'patternがゼロのとき' do
      it 'true を返すこと' do
        analyzer = described_class.new(match_info)
        expect(analyzer.empty?).to be true
      end
    end

    context 'patternがあるとき' do
      before { create_serve_pattern }

      it 'false を返すこと' do
        analyzer = described_class.new(match_info)
        expect(analyzer.empty?).to be false
      end
    end
  end
end
