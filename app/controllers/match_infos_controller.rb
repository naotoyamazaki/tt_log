class MatchInfosController < ApplicationController
  before_action :require_login
  before_action :set_match_info, only: %i[ show edit update destroy ]

  # GET /match_infos or /match_infos.json
  def index
    @q = current_user.match_infos.ransack(params[:q])
    @match_infos = @q.result.includes(:player, :opponent).order(created_at: :desc)
  end

  # GET /match_infos/1 or /match_infos/1.json
  def show
    @match_info = MatchInfo.find(params[:id])
    @serve_scores = @match_info.scores.where(batting_style: 'serve')
    @receive_scores = @match_info.scores.where(batting_style: 'receive')
  end

  # GET /match_infos/new
  def new
    @match_info = MatchInfo.new
    @match_info.scores.build(batting_style: :serve)
    @match_info.scores.build(batting_style: :receive)
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
  
    respond_to do |format|
      if @match_info.update(match_info_params.merge(player_id: player.id, opponent_id: opponent.id))
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
