class OpponentTypeAnalysesController < ApplicationController
  before_action :require_login

  DEFAULT_OPPONENT_PLAYSTYLE = "front_drive".freeze

  def show
    completed_match_infos = current_user.match_infos.completed.includes(:games).to_a
    @opponent_playstyle = resolve_opponent_playstyle(params[:opponent_playstyle], completed_match_infos)
    @win_rate_entry = build_win_rate_entry(completed_match_infos)
    @srp_analysis = build_srp_analysis
  end

  private

  def resolve_opponent_playstyle(requested_playstyle, completed_match_infos)
    return requested_playstyle if MatchInfo.opponent_playstyles.key?(requested_playstyle)

    most_common_opponent_playstyle(completed_match_infos)
  end

  # 完了試合数が最多の戦型をデフォルトとする。同数の場合はenum定義順の先頭、該当データが0件の場合はfront_drive。
  def most_common_opponent_playstyle(completed_match_infos)
    counts = Hash.new(0)
    completed_match_infos.each do |match_info|
      playstyle = match_info.opponent_playstyle
      counts[playstyle] += 1 if playstyle.present?
    end
    return DEFAULT_OPPONENT_PLAYSTYLE if counts.empty?

    max_count = counts.values.max
    MatchInfo.opponent_playstyles.keys.find { |key| counts[key] == max_count } || DEFAULT_OPPONENT_PLAYSTYLE
  end

  def build_win_rate_entry(completed_match_infos)
    entries = OpponentTypeWinRateAggregator.new(
      match_infos: completed_match_infos, attribute: :opponent_playstyle
    ).type_win_rates
    target_label = MatchInfo.human_enum_name(:opponent_playstyle, @opponent_playstyle)
    entries.find { |entry| entry[:type_label] == target_label }
  end

  # 決定率はanalysis_type: serve_receive かつ選択戦型の試合IDをまとめて取得し、1クエリでパターンを引く（N+1回避）。
  def build_srp_analysis
    match_ids = current_user.match_infos.completed
      .where(analysis_type: :serve_receive, opponent_playstyle: @opponent_playstyle)
      .pluck(:id)
    patterns = ServeReceivePattern.where(match_info_id: match_ids).order(:game_number, :sequence_number)
    ServeReceiveAnalyzer.new(patterns: patterns)
  end
end
