class MatchInfosController < ApplicationController
  before_action :require_login
  before_action :set_match_info, only: %i[ show edit update destroy ]

  # GET /match_infos or /match_infos.json
  def index
    @q = current_user.match_infos.ransack(params[:q])
    @pagy, @match_infos = pagy(@q.result.includes(:player, :opponent).order(created_at: :desc))
  end

  # GET /match_infos/1 or /match_infos/1.json
  def show
    @match_info = MatchInfo.find(params[:id])
    @serve_scores = @match_info.scores.where(batting_style: 'serve')
    @receive_scores = @match_info.scores.where(batting_style: 'receive')
    @batting_scores = @match_info.scores.where.not(batting_style: ['serve', 'receive'])

    # 得点率データを計算
    batting_score_data = prepare_batting_score_data(@batting_scores)
    Rails.logger.info("Data sent to ChatGPT API: #{batting_score_data.to_json}")
    # アドバイスが存在する場合は再生成せずに使用
    if @match_info.advice.present?
      @advice = @match_info.advice
    else
      @advice = ChatgptService.get_advice(batting_score_data.to_json)
      begin
        @match_info.update_columns(advice: @advice) # エラー発生時に例外をスロー
      rescue => e
        Rails.logger.error("Failed to update advice: #{e.record.errors.full_messages.join(", ")}")
      end
    end
  end

  # GET /match_infos/new
  def new
    @match_info = MatchInfo.new
    Score.batting_styles.keys.each do |batting_style|
      @match_info.scores.build(batting_style: batting_style)
    end
  end

  # GET /match_infos/1/edit
  def edit
    @match_info = MatchInfo.find(params[:id])
    @match_info.player_name = @match_info.player.player_name
    @match_info.opponent_name = @match_info.opponent.player_name
    @serve_scores = @match_info.scores.where(batting_style: :serve)
    @receive_scores = @match_info.scores.where(batting_style: :receive)
  end

  # POST /match_infos or /match_infos.json
  def create
    player = Player.find_or_create_by(player_name: params[:match_info][:player_name])
    opponent = Player.find_or_create_by(player_name: params[:match_info][:opponent_name])
  
    @match_info = MatchInfo.new(match_info_params.merge(player_id: player.id, opponent_id: opponent.id))
    @match_info.player_name = params[:match_info][:player_name]
    @match_info.opponent_name = params[:match_info][:opponent_name]

    @match_info.user = current_user
  
    respond_to do |format|
      if @match_info.save
        # Xへの投稿をユーザーが選択した場合のみ実行
        if params[:match_info][:post_to_x] == "1"
          message = "新しい試合分析データが作成され、Xに投稿されました!\n選手名: #{@match_info.player.player_name}、対戦相手: #{@match_info.opponent.player_name}、メモ: #{@match_info.memo}"
          TwitterClient.post_to_twitter(message)
        end

        format.html { redirect_to match_info_url(@match_info), notice: "試合分析データが作成されました。" }
        format.json { render :show, status: :created, location: @match_info }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @match_info.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /match_infos/1 or /match_infos/1.json
  def update
    player = Player.find_or_create_by(player_name: params[:match_info][:player_name])
    opponent = Player.find_or_create_by(player_name: params[:match_info][:opponent_name])

    @match_info.player_name = params[:match_info][:player_name]
    @match_info.opponent_name = params[:match_info][:opponent_name]

    # 変更前のbatting_score_dataを保持
    original_batting_score_data = calculate_batting_score_data(@match_info.scores.where.not(batting_style: ['serve', 'receive']))
  
    respond_to do |format|
      if @match_info.update(match_info_params.merge(player_id: player.id, opponent_id: opponent.id))
        # 変更後のbatting_score_dataを計算
        updated_batting_scores = @match_info.scores.where.not(batting_style: ['serve', 'receive'])
        updated_batting_score_data = prepare_batting_score_data(updated_batting_scores)
  
        # batting_score_dataが変更された場合のみGPT APIを呼び出す
        if original_batting_score_data != updated_batting_score_data
          new_advice = ChatgptService.get_advice(updated_batting_score_data.to_json)
          unless @match_info.update(advice: new_advice)
            Rails.logger.error("アドバイスの更新に失敗しました: #{@match_info.errors.full_messages}")
          end
        end
  
        format.html { redirect_to @match_info, notice: "試合分析データが更新されました。" }
        format.json { render :show, status: :ok, location: @match_info }
      else
        Rails.logger.info(@match_info.errors.full_messages)
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @match_info.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /match_infos/1 or /match_infos/1.json
  def destroy
    @match_info.destroy!

    respond_to do |format|
      format.html { redirect_to match_infos_url, alert: "試合分析データが削除されました。" }
      format.json { head :no_content }
    end
  end

  def autocomplete
    @match_infos = MatchInfo.search(params[:term])
    render json: @match_infos.map(&:name)
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_match_info
      @match_info = current_user.match_infos.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to match_infos_path, alert: "指定された投稿が見つかりません。"
    end

    # Only allow a list of trusted parameters through.
    def match_info_params
      params.require(:match_info).permit(:match_date, :match_name, :memo , :post_to_x, scores_attributes: [:id, :batting_style, :score, :lost_score, :_destroy])
    end
end
