class GrowthDashboardsController < ApplicationController
  before_action :require_login

  FORE_DRIVE_VS_TOPSPIN = "fore_drive_vs_topspin".freeze

  def index
    match_infos = current_user.match_infos.includes(:scores)
    @batting_style = FORE_DRIVE_VS_TOPSPIN
    @series = GrowthDashboardAggregator.new(
      match_infos: match_infos, batting_style: @batting_style
    ).monthly_rate_series
  end
end
