class GrowthDashboardsController < ApplicationController
  before_action :require_login

  DEFAULT_BATTING_STYLE = "fore_drive_vs_topspin".freeze
  DEFAULT_PERIOD = :month
  ALLOWED_PERIODS = %w[month week].freeze

  def index
    match_infos = current_user.match_infos.includes(:scores)
    @batting_style = resolve_batting_style(params[:batting_style])
    @period = resolve_period(params[:period])
    @series = GrowthDashboardAggregator.new(
      match_infos: match_infos, batting_style: @batting_style, period: @period
    ).monthly_usage_share_series
  end

  private

  def resolve_batting_style(requested_batting_style)
    return DEFAULT_BATTING_STYLE unless Score.allowed_batting_styles.include?(requested_batting_style)

    requested_batting_style
  end

  def resolve_period(requested_period)
    return DEFAULT_PERIOD unless ALLOWED_PERIODS.include?(requested_period)

    requested_period.to_sym
  end
end
