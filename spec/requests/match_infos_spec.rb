require 'rails_helper'

RSpec.describe "MatchInfos", type: :request do
  let(:user) { create(:user) }

  before do
    login_as(user)
  end

  describe "GET /match_infos" do
    it "一覧ページにアクセスできること" do
      get match_infos_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /match_infos/:id" do
    let(:match_info) { create(:match_info, user: user) }

    it "詳細ページにアクセスできること" do
      get match_info_path(match_info)
      expect(response).to have_http_status(:ok)
    end

    context "ゲームデータがある場合" do
      let!(:game) { create(:game, match_info: match_info, game_number: 1, player_score: 11, opponent_score: 8) }

      before do
        allow(ChatgptService).to receive(:get_advice).and_return("テストアドバイス")
      end

      it "詳細ページにゲームスコアが含まれること" do
        get match_info_path(match_info)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("11-8")
      end

      it "ゲーム別スコアセクションが表示されること" do
        get match_info_path(match_info)
        expect(response.body).to include("ゲーム別スコア")
      end
    end

    context "ラリーベースのゲームデータがある場合" do
      let!(:game) { create(:game, match_info: match_info, game_number: 1, player_score: 2, opponent_score: 1) }

      before do
        create(:score, match_info: match_info, game: game, batting_style: :serve, score: 1, lost_score: 0)
        create(:score, match_info: match_info, game: game, batting_style: :fore_push, score: 1, lost_score: 1)
        create(:rally, match_info: match_info, game: game, game_number: 1,
                       sequence_number: 1, winner: :player, batting_style: :serve)
        allow(ChatgptService).to receive(:get_advice).and_return("テストアドバイス")
      end

      it "自分と相手の得点技術ランキングが表示されること" do
        get match_info_path(match_info)

        expect(response.body).to include("自分の得点技術ランキング")
        expect(response.body).to include("相手の得点技術ランキング")
        expect(response.body).to include("ranking-table-player-header")
        expect(response.body).to include("ranking-table-opponent-header")
      end
    end

    context "旧形式のゲームデータがある場合" do
      let!(:game) { create(:game, match_info: match_info, game_number: 1, player_score: 3, opponent_score: 1) }

      before do
        create(:score, match_info: match_info, game: game, batting_style: :serve, score: 3, lost_score: 1)
        allow(ChatgptService).to receive(:get_advice).and_return("テストアドバイス")
      end

      it "従来の単一ランキングが表示されること" do
        get match_info_path(match_info)

        expect(response.body).to include("技術ごとの得点数ランキング")
        expect(response.body).not_to include("相手の得点技術ランキング")
      end
    end

    context "ゲームデータがない場合" do
      it "ゲーム別スコアセクションが表示されないこと" do
        get match_info_path(match_info)
        expect(response.body).not_to include("game-score-summary")
      end
    end

    context "serve_receive? な match_info の場合" do
      let(:srp_match_info) { create(:match_info, user: user, analysis_type: :serve_receive) }

      it "200を返すこと" do
        get match_info_path(srp_match_info)
        expect(response).to have_http_status(:ok)
      end

      it "@srp_analysis が ServeReceiveAnalyzer のインスタンスであること" do
        get match_info_path(srp_match_info)
        expect(controller.instance_variable_get(:@srp_analysis)).to be_a(ServeReceiveAnalyzer)
      end

      it "AIアドバイス処理が呼ばれないこと" do
        expect(ChatgptService).not_to receive(:get_advice)
        get match_info_path(srp_match_info)
      end
    end
  end

  describe "GET /match_infos/new" do
    it "新規作成ページにアクセスできること" do
      get new_match_info_path
      expect(response).to have_http_status(:ok)
    end

    context "draft_id が指定されている場合" do
      let(:draft) { create(:match_info, user: user) }

      it "下書き試合の情報を引き継いだフォームが表示される" do
        get new_match_info_path(draft_id: draft.id)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST /match_infos" do
    let(:params) do
      {
        match_info: attributes_for(:match_info).merge(
          player_name: "選手A",
          opponent_name: "選手B"
        ),
        game_scores: {
          "serve" => { "score" => "3", "lost_score" => "1" },
          "fore_drive_vs_topspin" => { "score" => "2", "lost_score" => "1" }
        }
      }
    end

    it "新規作成できること" do
      expect do
        post match_infos_path, params: params
      end.to change(MatchInfo, :count).by(1)
      expect(response).to redirect_to(MatchInfo.last)
    end

    it "ゲームと得点データが保存されること" do
      post match_infos_path, params: params
      match_info = MatchInfo.last
      expect(match_info.games.count).to eq(1)
      expect(match_info.games.first.player_score).to eq(5)
      expect(match_info.games.first.opponent_score).to eq(2)
      expect(match_info.scores.count).to eq(2)
    end
  end

  describe "POST /match_infos/end_game" do
    let(:game_scores) do
      {
        "serve" => { "score" => "5", "lost_score" => "2" },
        "fore_drive_vs_topspin" => { "score" => "6", "lost_score" => "3" }
      }
    end
    let(:match_info_params) do
      attributes_for(:match_info).merge(player_name: "選手A", opponent_name: "選手B")
    end

    context "下書きなし（1ゲーム目終了）" do
      it "MatchInfoと最初のゲームが作成されること" do
        expect do
          post end_game_match_infos_path, params: {
            match_info: match_info_params,
            game_scores: game_scores
          }
        end.to change(MatchInfo, :count).by(1).and change(Game, :count).by(1)

        draft = MatchInfo.last
        expect(draft.games.first.game_number).to eq(1)
        expect(draft.games.first.player_score).to eq(11)
        expect(draft.games.first.opponent_score).to eq(5)
        expect(response).to redirect_to(new_match_info_path(draft_id: draft.id))
      end
    end

    context "下書きあり（2ゲーム目以降）" do
      let!(:draft) { create(:match_info, user: user) }

      it "既存MatchInfoに新しいゲームが追加されること" do
        expect do
          post end_game_match_infos_path, params: {
            draft_id: draft.id,
            match_info: match_info_params,
            game_scores: game_scores
          }
        end.to change(Game, :count).by(1)

        expect(draft.games.count).to eq(1)
        expect(draft.games.first.game_number).to eq(1)
        expect(response).to redirect_to(new_match_info_path(draft_id: draft.id))
      end
    end
  end

  describe "DELETE /match_infos/undo_game" do
    context "下書きに1ゲームある場合" do
      let!(:draft) { create(:match_info, user: user, draft: true) }
      let!(:game) { create(:game, match_info: draft, game_number: 1, player_score: 11, opponent_score: 8) }

      it "ゲームのみ削除されてMatchInfoは残り draft のフォームへリダイレクトする" do
        expect do
          delete undo_game_match_infos_path, params: { draft_id: draft.id }
        end.to change(Game, :count).by(-1).and change(MatchInfo, :count).by(0)
        expect(response).to redirect_to(new_match_info_path(draft_id: draft.id))
      end
    end

    context "下書きに2ゲームある場合" do
      let!(:draft) { create(:match_info, user: user, draft: true) }
      let!(:game1) { create(:game, match_info: draft, game_number: 1, player_score: 11, opponent_score: 8) }
      let!(:game2) { create(:game, match_info: draft, game_number: 2, player_score: 9, opponent_score: 11) }

      it "最後のゲームのみ削除されて draft のフォームへリダイレクトする" do
        expect do
          delete undo_game_match_infos_path, params: { draft_id: draft.id }
        end.to change(Game, :count).by(-1).and change(MatchInfo, :count).by(0)
        expect(response).to redirect_to(new_match_info_path(draft_id: draft.id))
        expect(draft.reload.games.count).to eq(1)
      end
    end

    context "draft_id が存在しない場合" do
      it "新規フォームへリダイレクトする" do
        delete undo_game_match_infos_path, params: { draft_id: 999_999 }
        expect(response).to redirect_to(new_match_info_path)
      end
    end
  end

  describe "POST /match_infos/end_game (draft フラグ)" do
    let(:game_scores) do
      {
        "serve" => { "score" => "5", "lost_score" => "2" }
      }
    end
    let(:match_info_params) do
      attributes_for(:match_info).merge(player_name: "選手A", opponent_name: "選手B")
    end

    it "end_game 後に draft が true になること" do
      post end_game_match_infos_path, params: {
        match_info: match_info_params,
        game_scores: game_scores
      }
      expect(MatchInfo.last.draft).to be true
    end
  end

  describe "POST /match_infos（rallies パラメータあり）" do
    let(:rallies_data) do
      [
        { 'winner' => 'player', 'batting_style' => 'serve' },
        { 'winner' => 'player', 'batting_style' => 'fore_drive_vs_topspin' },
        { 'winner' => 'opponent', 'batting_style' => 'fore_drive_vs_topspin' },
        { 'winner' => 'player', 'batting_style' => 'serve' }
      ]
    end
    let(:params) do
      {
        match_info: attributes_for(:match_info).merge(
          player_name: "選手A",
          opponent_name: "選手B"
        ),
        rallies: rallies_data.to_json
      }
    end

    it 'Rally レコードが作成される' do
      expect do
        post match_infos_path, params: params
      end.to change(Rally, :count).by(4)
    end

    it 'Score レコードがラリーから集計されて作成される' do
      post match_infos_path, params: params
      match_info = MatchInfo.last
      # serve: player 2, opponent 0 / fore_drive_vs_topspin: player 1, opponent 1
      expect(match_info.scores.count).to eq(2)
      serve_score = match_info.scores.find_by(batting_style: :serve)
      expect(serve_score.score).to eq(2)
      expect(serve_score.lost_score).to eq(0)
      fd_score = match_info.scores.find_by(batting_style: :fore_drive_vs_topspin)
      expect(fd_score.score).to eq(1)
      expect(fd_score.lost_score).to eq(1)
    end

    it 'Game の player_score と opponent_score がラリーから集計される' do
      post match_infos_path, params: params
      game = MatchInfo.last.games.first
      expect(game.player_score).to eq(3)
      expect(game.opponent_score).to eq(1)
    end
  end

  describe "POST /match_infos（rallies パラメータなし ＝ 後方互換）" do
    let(:params) do
      {
        match_info: attributes_for(:match_info).merge(
          player_name: "選手A",
          opponent_name: "選手B"
        ),
        game_scores: {
          "serve" => { "score" => "3", "lost_score" => "1" }
        }
      }
    end

    it 'Rally レコードが作成されない' do
      expect do
        post match_infos_path, params: params
      end.not_to change(Rally, :count)
    end

    it 'Score レコードが game_scores から作成される' do
      post match_infos_path, params: params
      match_info = MatchInfo.last
      expect(match_info.scores.count).to eq(1)
      expect(match_info.scores.first.batting_style).to eq('serve')
      expect(match_info.scores.first.score).to eq(3)
    end
  end

  describe "POST /match_infos (draft フラグ)" do
    let(:params) do
      {
        match_info: attributes_for(:match_info).merge(
          player_name: "選手A",
          opponent_name: "選手B"
        ),
        game_scores: {
          "serve" => { "score" => "3", "lost_score" => "1" }
        }
      }
    end

    it "create 後に draft が false になること" do
      post match_infos_path, params: params
      expect(MatchInfo.last.draft).to be false
    end
  end

  describe "PATCH /match_infos/:id" do
    let(:match_info) { create(:match_info, user: user) }

    it "更新できること" do
      patch match_info_path(match_info), params: {
        match_info: { match_name: "更新後の試合名", player_name: "選手A", opponent_name: "選手B" }
      }
      expect(response).to redirect_to(match_info_path(match_info))
      expect(match_info.reload.match_name).to eq("更新後の試合名")
    end
  end

  describe "DELETE /match_infos/:id" do
    let!(:match_info) { create(:match_info, user: user) }

    it "削除できること" do
      expect do
        delete match_info_path(match_info)
      end.to change(MatchInfo, :count).by(-1)
      expect(response).to redirect_to(match_infos_path)
    end
  end

  describe "GET /match_infos/new_serve_receive" do
    it "200を返すこと" do
      get new_serve_receive_match_infos_path
      expect(response).to have_http_status(:ok)
    end

    it "未ログインの場合はリダイレクトされること" do
      delete logout_path
      get new_serve_receive_match_infos_path
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "POST /match_infos/create_serve_receive" do
    let(:patterns_data) do
      [
        { 'origin' => 'serve', 'serve_length' => 'short', 'serve_spins' => [0],
          'receive_style' => nil, 'attack_style' => 'fore_drive_vs_backspin',
          'decided_at' => 'attack_ball', 'won' => true },
        { 'origin' => 'receive', 'serve_length' => nil, 'serve_spins' => [],
          'receive_style' => 'chiquita', 'attack_style' => 'back_drive_vs_topspin',
          'decided_at' => 'follow_ball', 'won' => false }
      ]
    end
    let(:params) do
      {
        match_info: attributes_for(:match_info).merge(
          player_name: "選手A",
          opponent_name: "選手B"
        ),
        patterns: patterns_data.to_json,
        first_server: 'player'
      }
    end

    it "ServeReceivePattern レコードが作成されること" do
      expect do
        post create_serve_receive_match_infos_path, params: params
      end.to change(ServeReceivePattern, :count).by(2)
    end

    it "MatchInfo が analysis_type: serve_receive で作成されること" do
      post create_serve_receive_match_infos_path, params: params
      expect(MatchInfo.last.analysis_type).to eq('serve_receive')
    end

    it "未ログインの場合はリダイレクトされること" do
      delete logout_path
      post create_serve_receive_match_infos_path, params: params
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "POST /match_infos/end_game_serve_receive" do
    let(:patterns_data) do
      Array.new(13) do |i|
        { 'origin' => 'serve', 'serve_length' => 'short', 'serve_spins' => [0],
          'receive_style' => nil, 'attack_style' => 'fore_drive_vs_backspin',
          'decided_at' => 'attack_ball', 'won' => i < 11 }
      end
    end
    let(:params) do
      {
        match_info: attributes_for(:match_info).merge(
          player_name: "選手A",
          opponent_name: "選手B"
        ),
        patterns: patterns_data.to_json,
        first_server: 'player'
      }
    end

    it "Game が作成されること" do
      expect do
        post end_game_serve_receive_match_infos_path, params: params
      end.to change(Game, :count).by(1)
    end

    it "ServeReceivePattern が作成されること" do
      expect do
        post end_game_serve_receive_match_infos_path, params: params
      end.to change(ServeReceivePattern, :count).by(13)
    end

    it "new_serve_receive フォームへリダイレクトすること" do
      post end_game_serve_receive_match_infos_path, params: params
      draft = MatchInfo.last
      expect(response).to redirect_to(new_serve_receive_match_infos_path(draft_id: draft.id))
    end
  end

  describe "POST /match_infos/interrupt (serve_receive)" do
    let(:patterns_json) do
      [{ origin: 'serve', serve_length: 'short', serve_spins: [0], attack_style: 'fore_drive_vs_backspin',
         decided_at: 'attack_ball', won: true }].to_json
    end
    let(:base_params) do
      {
        match_info: attributes_for(:match_info).merge(
          player_name: "選手A", opponent_name: "選手B", analysis_type: 'serve_receive'
        ),
        patterns: patterns_json,
        first_server: 'player'
      }
    end

    it "patterns を partial_game_data に保存すること" do
      post interrupt_match_infos_path, params: base_params
      draft = MatchInfo.last
      expect(draft.partial_game_data['patterns']).to eq(patterns_json)
    end

    it "一覧ページへリダイレクトすること" do
      post interrupt_match_infos_path, params: base_params
      expect(response).to redirect_to(match_infos_path)
    end
  end

  describe "DELETE /match_infos/undo_game (serve_receive)" do
    let!(:draft) { create(:match_info, user: user, draft: true, analysis_type: :serve_receive) }
    let!(:game) do
      create(:game, match_info: draft, game_number: 1, player_score: 3, opponent_score: 2, first_server: 'player')
    end
    let!(:srp) do
      create(:serve_receive_pattern, match_info: draft, game: game,
                                     game_number: 1, sequence_number: 1,
                                     origin: :serve, serve_length: :short, serve_spins: [0],
                                     attack_style: :fore_drive_vs_backspin, decided_at: :attack_ball, won: true)
    end

    it "ゲームとパターンが削除されること" do
      expect do
        delete undo_game_match_infos_path, params: { draft_id: draft.id }
      end.to change(Game, :count).by(-1).and change(ServeReceivePattern, :count).by(-1)
    end

    it "new_serve_receive フォームへリダイレクトすること" do
      delete undo_game_match_infos_path, params: { draft_id: draft.id }
      expect(response).to redirect_to(new_serve_receive_match_infos_path(draft_id: draft.id))
    end

    it "partial_game_data に patterns が保存されること" do
      delete undo_game_match_infos_path, params: { draft_id: draft.id }
      expect(draft.reload.partial_game_data).to have_key('patterns')
    end
  end
end
