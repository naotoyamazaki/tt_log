class GrowthDashboardsController < ApplicationController
  before_action :require_login

  DEFAULT_BATTING_STYLE = "fore_drive_vs_topspin".freeze
  DEFAULT_PERIOD = :month
  ALLOWED_PERIODS = %w[month week].freeze
  # 将来的に他の対戦相手属性でも同じ仕組みで絞り込みを追加できるよう、
  # 「パラメータ名 => 許可するenumキー一覧」をハッシュで持つ。
  OPPONENT_ATTRIBUTE_FILTERS = {
    opponent_playstyle: -> { MatchInfo.opponent_playstyles.keys }
  }.freeze

  def index
    all_match_infos = current_user.match_infos.completed.includes(:scores, :games)
    @opponent_playstyle = resolve_opponent_playstyle(params[:opponent_playstyle])
    @batting_style = resolve_batting_style(params[:batting_style])
    @period = resolve_period(params[:period])
    @series = build_series(all_match_infos)
    @opponent_type_win_rates = build_opponent_type_win_rates(all_match_infos)
  end

  private

  def build_series(all_match_infos)
    filtered_match_infos = apply_opponent_attribute_filters(all_match_infos)
    GrowthDashboardAggregator.new(
      match_infos: filtered_match_infos, batting_style: @batting_style, period: @period
    ).monthly_usage_share_series
  end

  # 戦型別勝率は「戦型ごとの内訳」そのものを見せる表のため、戦型フィルタの影響を受けず全期間・全戦型を対象にする。
  def build_opponent_type_win_rates(all_match_infos)
    OpponentTypeWinRateAggregator.new(
      match_infos: all_match_infos, attribute: :opponent_playstyle
    ).type_win_rates
  end

  def apply_opponent_attribute_filters(match_infos)
    OPPONENT_ATTRIBUTE_FILTERS.each do |param_name, allowed_keys_proc|
      requested_value = params[param_name]
      next unless allowed_keys_proc.call.include?(requested_value)

      match_infos = match_infos.where(param_name => requested_value)
    end
    match_infos
  end

  def resolve_opponent_playstyle(requested_playstyle)
    return nil unless MatchInfo.opponent_playstyles.key?(requested_playstyle)

    requested_playstyle
  end

  def resolve_batting_style(requested_batting_style)
    return DEFAULT_BATTING_STYLE unless Score.allowed_batting_styles.include?(requested_batting_style)

    requested_batting_style
  end

  def resolve_period(requested_period)
    return DEFAULT_PERIOD unless ALLOWED_PERIODS.include?(requested_period)

    requested_period.to_sym
  end
end
