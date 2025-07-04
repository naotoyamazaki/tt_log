class MatchInfosController < ApplicationController
  before_action :require_login
  before_action :set_match_info, only: %i[show edit update destroy]

  # GET /match_infos or /match_infos.json
  def index
    @q = current_user.match_infos.ransack(params[:q])
    @pagy, @match_infos = pagy(@q.result.includes(:player, :opponent).order(created_at: :desc))
  end

  def show
    set_match_info_scores
    if @match_info.advice.present?
      @advice = @match_info.advice
    else
      AdviceGenerationJob.perform_later(@match_info.id)
      @advice = t('messages.advice_generating')
    end
  end

  # GET /match_infos/new
  def new
    @match_info = MatchInfo.new
    Score.batting_styles.each_key do |batting_style|
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
    player, opponent = find_or_create_players
    @match_info = build_match_info(player, opponent)

    respond_to do |format|
      if @match_info.save
        format.html { redirect_to match_info_url(@match_info), notice: t('notices.match_info_created') }
        format.json { render :show, status: :created, location: @match_info }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @match_info.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /match_infos/1 or /match_infos/1.json
  def update
    set_players
    original_batting_score_data = fetch_batting_score_data(@match_info)

    if update_match_info
      update_advice_if_needed(original_batting_score_data)
      update_response(success: true, notice: t('messages.advice_generating'))
    else
      update_response(success: false)
    end
  end

  # DELETE /match_infos/1 or /match_infos/1.json
  def destroy
    @match_info.destroy!

    respond_to do |format|
      format.html { redirect_to match_infos_url, alert: t('notices.match_info_deleted') }
      format.json { head :no_content }
    end
  end

  def autocomplete
    @match_infos = MatchInfo.search(params[:term])
    render json: @match_infos.map(&:name)
  end

  private

  # show
  def set_match_info_scores
    @match_info = MatchInfo.find(params[:id])
    @serve_scores = @match_info.scores.where(batting_style: 'serve')
    @receive_scores = @match_info.scores.where(batting_style: 'receive')
    @batting_scores = @match_info.scores.where.not(batting_style: ['serve', 'receive'])
  end

  # create
  def find_or_create_players
    player = Player.find_or_create_by(player_name: params[:match_info][:player_name])
    opponent = Player.find_or_create_by(player_name: params[:match_info][:opponent_name])
    [player, opponent]
  end

  def build_match_info(player, opponent)
    MatchInfo.new(match_info_params).tap do |match_info|
      match_info.player_id = player.id
      match_info.opponent_id = opponent.id
      match_info.player_name = player.player_name
      match_info.opponent_name = opponent.player_name
      match_info.user = current_user
    end
  end

  # update
  # プレイヤー情報の設定
  def set_players
    @player = Player.find_or_create_by(player_name: params[:match_info][:player_name])
    @opponent = Player.find_or_create_by(player_name: params[:match_info][:opponent_name])
    @match_info.player_name = params[:match_info][:player_name]
    @match_info.opponent_name = params[:match_info][:opponent_name]
  end

  # match_infoを更新
  def update_match_info
    @match_info.update(match_info_params.merge(player_id: @player.id, opponent_id: @opponent.id))
  end

  # バッティングスコアデータの取得
  def fetch_batting_score_data(match_info)
    match_info.scores.where.not(batting_style: ['serve', 'receive']).map do |score|
      { batting_style: score.batting_style, score: score.score, lost_score: score.lost_score }
    end
  end

  # 必要に応じてアドバイスを更新
  def update_advice_if_needed(original_data)
    return unless batting_score_changed?(original_data)

    AdviceGenerationJob.perform_later(@match_info.id)
  end

  # バッティングスコアが変更されたか判定
  def batting_score_changed?(original_data)
    original_data != fetch_batting_score_data(@match_info)
  end

  # 更新成功・失敗時のレスポンス
  def update_response(success:, notice: nil)
    respond_to do |format|
      if success
        format.html { redirect_to @match_info, notice: notice || t('notices.match_info_updated') }
        format.json { render :show, status: :ok, location: @match_info }
      else
        log_update_errors
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @match_info.errors, status: :unprocessable_entity }
      end
    end
  end

  # 更新失敗時のログ出力
  def log_update_errors
    Rails.logger.info(@match_info.errors.full_messages)
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_match_info
    @match_info = current_user.match_infos.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to match_infos_path, alert: t('notices.match_info_not_found')
  end

  # Only allow a list of trusted parameters through.
  def match_info_params
    params.require(:match_info).permit(
      :match_date, :match_name, :memo, :post_to_x, scores_attributes: [
        :id, :batting_style, :score, :lost_score, :_destroy
      ]
    )
  end
end
