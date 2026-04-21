class MatchInfosController < ApplicationController # rubocop:disable Metrics/ClassLength
  before_action :require_login
  before_action :set_match_info, only: %i[show edit update destroy]

  def index
    @q = current_user.match_infos.ransack(params[:q])
    @pagy, @match_infos = pagy(@q.result.includes(:player, :opponent).order(created_at: :desc))
  end

  def show
    set_match_info_scores
    if @match_info.advice.present?
      @advice = @match_info.advice
    else
      game_data = @match_info.game_by_game_score_data
      advice = ChatgptService.get_advice(@match_info.batting_score_data.to_json, game_data)
      @match_info.update_advice(advice)
      @advice = advice
    end
  end

  def new
    if params[:draft_id].present?
      draft = current_user.match_infos.find_by(id: params[:draft_id])
      if draft
        setup_draft_form(draft)
        return
      end
    end
    setup_new_form
  end

  def edit
    @match_info = MatchInfo.find(params[:id])
    @match_info.player_name = @match_info.player.player_name
    @match_info.opponent_name = @match_info.opponent.player_name
  end

  def end_game
    player, opponent = find_or_create_players
    @match_info = draft_or_new_match_info(player, opponent)

    unless @match_info.valid?
      set_form_state_for_error
      render :new, status: :unprocessable_entity
      return
    end

    @match_info.save! unless @match_info.persisted?
    @match_info.save! if @match_info.changed?
    create_game_with_scores(@match_info)
    @match_info.update!(draft: true, partial_game_data: nil)
    redirect_to new_match_info_path(draft_id: @match_info.id)
  end

  def interrupt
    player, opponent = find_or_create_players
    @match_info = draft_or_new_match_info(player, opponent)
    @match_info.assign_attributes(match_info_params)
    @match_info.draft = true
    @match_info.partial_game_data = game_score_params.to_h
    @match_info.save!
    redirect_to match_infos_path, notice: t('notices.match_info_interrupted')
  end

  def restore_autosave
    player = Player.find_or_create_by(player_name: params[:player_name].to_s)
    opponent = Player.find_or_create_by(player_name: params[:opponent_name].to_s)
    @match_info = build_autosave_match_info(player, opponent)
    @match_info.save!(validate: false)
    redirect_to new_match_info_path(draft_id: @match_info.id)
  end

  def undo_game
    @match_info = current_user.match_infos.find_by(id: params[:draft_id])
    return redirect_to new_match_info_path unless @match_info

    delete_last_game(@match_info)
    redirect_after_undo(@match_info)
  end

  def create # rubocop:disable Metrics/AbcSize
    player, opponent = find_or_create_players
    @match_info = draft_or_new_match_info(player, opponent)

    respond_to do |format|
      if @match_info.save
        create_game_with_scores(@match_info)
        @match_info.update(draft: false)
        format.html { redirect_to match_info_url(@match_info), notice: t('notices.match_info_created') }
        format.json { render :show, status: :created, location: @match_info }
      else
        set_form_state_for_error
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @match_info.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    set_players
    original_batting_score_data = fetch_batting_score_data(@match_info)

    if update_match_info
      @match_info.games.each(&:recalculate_scores)
      update_advice_if_needed(original_batting_score_data)
      update_response(success: true, notice: t('notices.match_info_updated'))
    else
      update_response(success: false)
    end
  end

  def destroy
    @match_info.destroy!
    respond_to do |format|
      format.html { redirect_to match_infos_url, alert: t('notices.match_info_deleted') }
      format.json { head :no_content }
    end
  end

  def autocomplete
    candidates = autocomplete_candidates(params[:field], params[:q])
    render partial: "match_infos/autocomplete_results", locals: { candidates: candidates.first(10) }
  end

  private

  def setup_new_form
    @match_info = MatchInfo.new
    @draft_id = nil
    @saved_games = []
    @current_game_number = 1
    @max_games = 5
    @partial_scores = {}
  end

  def setup_draft_form(draft)
    @match_info = draft
    @match_info.player_name = draft.player.player_name
    @match_info.opponent_name = draft.opponent.player_name
    @draft_id = draft.id
    @saved_games = draft.games.order(:game_number)
    @current_game_number = @saved_games.count + 1
    @max_games = draft.match_format
    @partial_scores = draft.partial_game_data || {}
  end

  def draft_or_new_match_info(player, opponent) # rubocop:disable Metrics/AbcSize
    base_params = basic_match_info_params.merge(player_id: player.id, opponent_id: opponent.id)
    match_info = if params[:draft_id].present?
                   current_user.match_infos.find(params[:draft_id]).tap { |m| m.assign_attributes(base_params) }
                 else
                   current_user.match_infos.new(base_params)
                 end
    match_info.player_name = params[:match_info][:player_name]
    match_info.opponent_name = params[:match_info][:opponent_name]
    match_info
  end

  def set_form_state_for_error
    @draft_id = params[:draft_id]
    @max_games = @match_info.match_format || 5
    if @match_info.persisted?
      @saved_games = @match_info.games.order(:game_number)
      @current_game_number = @saved_games.count + 1
    else
      @saved_games = []
      @current_game_number = 1
    end
  end

  def create_game_with_scores(match_info)
    scores_data = game_score_params
    game_number = match_info.games.count + 1
    player_total = scores_data.values.sum { |s| s["score"].to_i }
    opponent_total = scores_data.values.sum { |s| s["lost_score"].to_i }
    game = match_info.games.create!(
      game_number: game_number, player_score: player_total, opponent_score: opponent_total
    )
    persist_game_scores(match_info, game, scores_data)
  end

  def persist_game_scores(match_info, game, scores_data)
    scores_data.each do |batting_style, values|
      next unless Score.batting_styles.key?(batting_style.to_s)

      match_info.scores.create!(
        game_id: game.id,
        batting_style: batting_style,
        score: values["score"].to_i,
        lost_score: values["lost_score"].to_i
      )
    end
  end

  def autocomplete_candidates(field, term)
    query = "%#{term}%"
    case field
    when "match_name"
      current_user.match_infos.where("match_name ILIKE ?", query).distinct.pluck(:match_name)
    when "player_name"
      autocomplete_players(:match_infos_as_player, query)
    when "opponent_name"
      autocomplete_players(:match_infos_as_opponent, query)
    else
      []
    end
  end

  def autocomplete_players(association, query)
    Player.joins(association)
      .where(match_infos: { user_id: current_user.id })
      .where("players.player_name ILIKE ?", query)
      .distinct.pluck(:player_name)
  end

  def set_match_info_scores
    @match_info = MatchInfo.find(params[:id])
    @batting_scores = @match_info.scores.where.not(batting_style: :receive)
  end

  def find_or_create_players
    player = Player.find_or_create_by(player_name: params[:match_info][:player_name])
    opponent = Player.find_or_create_by(player_name: params[:match_info][:opponent_name])
    [player, opponent]
  end

  def set_players
    @player = Player.find_or_create_by(player_name: params[:match_info][:player_name])
    @opponent = Player.find_or_create_by(player_name: params[:match_info][:opponent_name])
    @match_info.player_name = params[:match_info][:player_name]
    @match_info.opponent_name = params[:match_info][:opponent_name]
  end

  def update_match_info
    @match_info.update(match_info_params.merge(player_id: @player.id, opponent_id: @opponent.id))
  end

  def fetch_batting_score_data(match_info)
    match_info.scores.where.not(batting_style: :receive).map do |score|
      { batting_style: score.batting_style, score: score.score, lost_score: score.lost_score }
    end
  end

  def update_advice_if_needed(original_data)
    return unless batting_score_changed?(original_data)

    @match_info.update_advice(nil)
    game_data = @match_info.game_by_game_score_data
    advice = ChatgptService.get_advice(@match_info.batting_score_data.to_json, game_data)
    @match_info.update_advice(advice)
  end

  def batting_score_changed?(original_data)
    original_data != fetch_batting_score_data(@match_info)
  end

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

  def log_update_errors
    Rails.logger.info(@match_info.errors.full_messages)
  end

  def set_match_info
    @match_info = current_user.match_infos.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to match_infos_path, alert: t('notices.match_info_not_found')
  end

  def delete_last_game(match_info)
    last_game = match_info.games.order(:game_number).last
    last_game&.destroy
  end

  def redirect_after_undo(match_info)
    if match_info.games.empty?
      match_info.destroy
      redirect_to new_match_info_path
    else
      redirect_to new_match_info_path(draft_id: match_info.id)
    end
  end

  def build_autosave_match_info(player, opponent)
    match_info = current_user.match_infos.new(
      match_date: params[:match_date],
      match_name: params[:match_name],
      memo: params[:memo],
      match_format: params[:match_format] || 5,
      player: player,
      opponent: opponent,
      draft: true
    )
    match_info.partial_game_data = JSON.parse(params[:game_scores] || '{}')
    match_info
  end

  def basic_match_info_params
    params.require(:match_info).permit(:match_date, :match_name, :memo, :match_format)
  end

  def game_score_params
    params[:game_scores]&.to_unsafe_h || {}
  end

  def match_info_params
    params.require(:match_info).permit(
      :match_date, :match_name, :memo,
      scores_attributes: [:id, :batting_style, :score, :lost_score, :_destroy],
      games_attributes: [
        :id,
        { scores_attributes: [:id, :batting_style, :score, :lost_score] }
      ]
    )
  end
end
