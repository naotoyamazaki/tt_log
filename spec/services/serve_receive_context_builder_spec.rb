require 'rails_helper'

RSpec.describe ServeReceiveContextBuilder do
  let(:user) { create(:user) }
  let(:match_info) { create(:match_info, user: user, analysis_type: :serve_receive) }

  describe 'データなしの場合' do
    subject(:builder) { described_class.new(match_info) }

    it 'serve_analysis_text が例外を出さず文字列を返すこと' do
      expect { builder.send(:serve_analysis_text) }.not_to raise_error
      expect(builder.send(:serve_analysis_text)).to be_a(String)
    end

    it 'receive_analysis_text が例外を出さず文字列を返すこと' do
      expect { builder.send(:receive_analysis_text) }.not_to raise_error
      expect(builder.send(:receive_analysis_text)).to be_a(String)
    end

    it 'timing_analysis_text が例外を出さず文字列を返すこと' do
      expect { builder.send(:timing_analysis_text) }.not_to raise_error
      expect(builder.send(:timing_analysis_text)).to be_a(String)
    end

    it 'build_context が例外を出さず文字列を返すこと' do
      expect { builder.build_context }.not_to raise_error
      expect(builder.build_context).to be_a(String)
    end
  end

  describe 'データありの場合' do
    let!(:game) { create(:game, match_info: match_info, game_number: 1, player_score: 3, opponent_score: 2) }
    let!(:srp1) do
      create(:serve_receive_pattern, match_info: match_info, game: game,
                                     game_number: 1, sequence_number: 1,
                                     origin: :serve, serve_length: :short, serve_spins: [0],
                                     attack_style: :fore_drive_vs_backspin, decided_at: :attack_ball, won: true)
    end
    let!(:srp2) do
      create(:serve_receive_pattern, match_info: match_info, game: game,
                                     game_number: 1, sequence_number: 2,
                                     origin: :receive, serve_length: nil, serve_spins: [],
                                     receive_style: ServeReceivePattern::RECEIVE_STYLE_VALUES[:chiquita],
                                     attack_style: :back_drive_vs_topspin, decided_at: :follow_ball, won: false)
    end

    subject(:builder) { described_class.new(match_info) }

    it 'serve_analysis_text が空でない文字列を返すこと' do
      expect(builder.send(:serve_analysis_text)).not_to be_empty
    end

    it 'timing_analysis_text にサーブ起点とレシーブ起点の両方が含まれること' do
      text = builder.send(:timing_analysis_text)
      expect(text).to include('サーブ起点')
      expect(text).to include('レシーブ起点')
    end

    it 'build_context に全セクションが含まれること' do
      context = builder.build_context
      expect(context).to include('【サーブ起点の分析】')
      expect(context).to include('【レシーブ起点の分析】')
      expect(context).to include('【得点タイミング】')
    end
  end
end
