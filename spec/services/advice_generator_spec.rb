require 'rails_helper'

RSpec.describe AdviceGenerator do
  let(:match_info) { create(:match_info) }

  before do
    allow(ChatgptService).to receive(:get_advice).and_return("新しいアドバイス")
    allow(ChatgptService).to receive(:get_serve_receive_advice).and_return("SRアドバイス")
  end

  it "成功時は advice を保存し :generated を返すこと" do
    expect(described_class.call(match_info)).to eq(:generated)
    expect(match_info.reload).to have_attributes(advice: "新しいアドバイス", advice_failed_at: nil,
                                                 advice_generating_at: nil)
  end

  it "失敗時は advice を保存せず advice_failed_at を記録すること" do
    allow(ChatgptService).to receive(:get_advice).and_return(nil)
    expect(described_class.call(match_info)).to eq(:failed)
    match_info.reload
    expect(match_info.advice).to be_nil
    expect(match_info.advice_failed_at).to be_present
    expect(match_info.advice_generating_at).to be_nil
  end

  it "例外が起きても失敗として扱い claim を解除すること" do
    allow(ChatgptService).to receive(:get_advice).and_raise(StandardError)
    expect(described_class.call(match_info)).to eq(:failed)
    expect(match_info.reload.advice_generating_at).to be_nil
  end

  it "有効なアドバイスがあれば API を呼ばず :existing を返すこと" do
    match_info.update_columns(advice: "既存") # rubocop:disable Rails/SkipsModelValidations
    expect(described_class.call(match_info)).to eq(:existing)
    expect(ChatgptService).not_to have_received(:get_advice)
  end

  it "他リクエストが生成中（claim有効）なら API を呼ばず :busy を返すこと" do
    match_info.update_columns(advice_generating_at: 10.seconds.ago) # rubocop:disable Rails/SkipsModelValidations
    expect(described_class.call(match_info)).to eq(:busy)
    expect(ChatgptService).not_to have_received(:get_advice)
  end

  it "45秒より古い claim は再取得して生成すること" do
    match_info.update_columns(advice_generating_at: 60.seconds.ago) # rubocop:disable Rails/SkipsModelValidations
    expect(described_class.call(match_info)).to eq(:generated)
  end

  it "保存済みの旧失敗文言は未生成として扱い、成功時に上書きすること" do
    match_info.update_columns(advice: MatchInfo::LEGACY_FAILURE_ADVICE) # rubocop:disable Rails/SkipsModelValidations
    expect(match_info.advice_available?).to be false
    expect(described_class.call(match_info)).to eq(:generated)
    expect(match_info.reload.advice).to eq("新しいアドバイス")
  end

  it "失敗時、旧失敗文言以外の既存の正常アドバイスは変更しないこと" do
    match_info.update_columns(advice: "正常") # rubocop:disable Rails/SkipsModelValidations
    described_class.call(match_info)
    expect(match_info.reload.advice).to eq("正常")
  end

  it "serve_receive の試合ではサーブ・レシーブ用の生成を呼ぶこと" do
    srp = create(:match_info, analysis_type: :serve_receive)
    expect(described_class.call(srp)).to eq(:generated)
    expect(srp.reload.advice).to eq("SRアドバイス")
    expect(ChatgptService).not_to have_received(:get_advice)
  end
end
