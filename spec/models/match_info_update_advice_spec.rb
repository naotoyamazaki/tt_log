# spec/requests/match_infos_update_spec.rb
require 'rails_helper'

RSpec.describe "MatchInfos#update", type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:match_info) do
    create(
      :match_info,
      user: user,
      advice: "old",
      match_name: "テスト大会",
      match_date: Date.current
    )
  end
  let!(:serve_score) { create(:score, match_info: match_info, batting_style: :serve, score: 1, lost_score: 1) }

  before do
    ActiveJob::Base.queue_adapter = :test

    post login_path, params: { email: user.email, password: 'password' }
    follow_redirect! if response.redirect?
  end

  def valid_base_params
    {
      match_name: "テスト大会",
      match_date: Date.current,
      player_name: "田中",
      opponent_name: "佐藤"
    }
  end

  it "打撃スコアが変わったら advice を nil にし、ジョブをenqueueする" do
    expect do
      patch match_info_path(match_info), params: {
        match_info: valid_base_params.merge(
          scores_attributes: {
            "0" => {
              id: serve_score.id,
              batting_style: "serve",
              score: 3,
              lost_score: 1,
              _destroy: "false"
            }
          }
        )
      }
    end.to have_enqueued_job(AdviceGenerationJob)

    expect(response).to have_http_status(:found).or have_http_status(:see_other)
    match_info.reload
    expect(match_info.advice).to be_nil
  end

  it "打撃スコアが変わらなければ advice を維持し、ジョブをenqueueしない" do
    expect do
      patch match_info_path(match_info), params: {
        match_info: valid_base_params.merge(
          scores_attributes: {
            "0" => {
              id: serve_score.id,
              batting_style: "serve",
              score: 1,
              lost_score: 1,
              _destroy: "false"
            }
          }
        )
      }
    end.not_to have_enqueued_job(AdviceGenerationJob)

    expect(response).to have_http_status(:found).or have_http_status(:see_other)
    match_info.reload
    expect(match_info.advice).to eq("old")
  end
end
