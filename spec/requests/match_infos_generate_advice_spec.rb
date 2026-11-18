require 'rails_helper'

RSpec.describe "アドバイスの表示と再試行", type: :request do
  let(:user) { create(:user) }
  let(:match_info) { create(:match_info, user: user) }

  describe "GET /match_infos/:id" do
    before { login_as(user) }

    it "保存済みの有効なアドバイスを再利用し、APIを呼ばないこと" do
      match_info.update_columns(advice: "保存済みアドバイス") # rubocop:disable Rails/SkipsModelValidations
      expect(ChatgptService).not_to receive(:get_advice)
      get match_info_path(match_info)
      expect(response.body).to include("保存済みアドバイス")
    end

    it "未生成なら自動生成して保存すること" do
      allow(ChatgptService).to receive(:get_advice).and_return("生成結果")
      get match_info_path(match_info)
      expect(response.body).to include("生成結果")
      expect(match_info.reload.advice).to eq("生成結果")
    end

    it "生成に失敗しても200を返し、失敗は保存されず再試行ボタンが出ること" do
      allow(ChatgptService).to receive(:get_advice).and_return(nil)
      get match_info_path(match_info)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("もう一度生成する")
      expect(match_info.reload.advice).to be_nil
    end

    it "失敗済みの試合はリロードしても自動再生成しないこと" do
      match_info.update_columns(advice_failed_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
      expect(ChatgptService).not_to receive(:get_advice)
      get match_info_path(match_info)
      expect(response.body).to include("もう一度生成する")
    end

    it "旧失敗文言が保存されていれば再生成して回復すること" do
      match_info.update_columns(advice: MatchInfo::LEGACY_FAILURE_ADVICE) # rubocop:disable Rails/SkipsModelValidations
      allow(ChatgptService).to receive(:get_advice).and_return("回復したアドバイス")
      get match_info_path(match_info)
      expect(match_info.reload.advice).to eq("回復したアドバイス")
    end
  end

  describe "POST /match_infos/:id/generate_advice" do
    it "未ログインはログイン画面へリダイレクトされること" do
      post generate_advice_match_info_path(match_info)
      expect(response).to have_http_status(:found)
      expect(ChatgptService).not_to receive(:get_advice)
    end

    it "本人なら再生成して詳細へ戻ること" do
      login_as(user)
      match_info.update_columns(advice_failed_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
      allow(ChatgptService).to receive(:get_advice).and_return("再生成")
      post generate_advice_match_info_path(match_info)
      expect(response).to redirect_to(match_info_path(match_info))
      expect(match_info.reload).to have_attributes(advice: "再生成", advice_failed_at: nil)
    end

    it "他ユーザーの試合には生成を実行しないこと" do
      other = create(:match_info)
      login_as(user)
      expect(ChatgptService).not_to receive(:get_advice)
      post generate_advice_match_info_path(other)
      expect(response).to redirect_to(match_infos_path)
      expect(other.reload.advice).to be_nil
    end
  end
end

RSpec.describe "GET /match_infos/:id/edit のユーザースコープ", type: :request do
  let(:user) { create(:user) }

  before { login_as(user) }

  it "他ユーザーの試合の編集画面は開けず一覧へリダイレクトされること" do
    other = create(:match_info, match_name: "他人の大会")
    get edit_match_info_path(other)
    expect(response).to redirect_to(match_infos_path)
    expect(response.body).not_to include("他人の大会")
  end

  it "自分の試合の編集画面は開けること" do
    get edit_match_info_path(create(:match_info, user: user))
    expect(response).to have_http_status(:ok)
  end
end
