require 'rails_helper'
require 'socket'

RSpec.describe OpenaiClient do
  # 1接続だけ受け付けて指定のレスポンスを返す疑似サーバー
  def start_server(status: 200, body: "", delay: 0)
    server = TCPServer.new("127.0.0.1", 0)
    thread = Thread.new do
      client = server.accept
      read_request(client)
      sleep delay
      client.write("HTTP/1.1 #{status} X\r\nContent-Type: application/json\r\n" \
                   "Content-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
      client.close
    rescue StandardError
      nil
    end
    [server, thread]
  end

  def read_request(client)
    headers = +""
    headers << client.gets until headers.end_with?("\r\n\r\n")
    length = headers[/Content-Length: (\d+)/i, 1].to_i
    client.read(length)
  end

  def call_client(**opts)
    described_class.chat(feature: "match_advice", system: "sys", user_prompt: "usr", **opts)
  end

  def with_server(**opts)
    server, thread = start_server(**opts)
    ENV["OPENAI_API_URL"] = "http://127.0.0.1:#{server.addr[1]}/v1/chat/completions"
    yield
  ensure
    ENV["OPENAI_API_URL"] = "http://127.0.0.1:9/v1/chat/completions"
    thread&.kill
    server&.close
  end

  let(:ok_body) do
    { choices: [{ message: { content: "  アドバイス本文  " } }],
      usage: { prompt_tokens: 10, completion_tokens: 20, total_tokens: 30 } }.to_json
  end
  let(:user) { create(:user) }

  before { allow(ENV).to receive(:fetch).and_call_original }

  it "成功時は content と usage を返し、使用量を記録すること" do
    with_server(body: ok_body) do
      result = call_client(user: user)
      expect(result).to be_success
      expect(result.content).to eq("アドバイス本文")
    end
    log = AiUsageLog.last
    expect(log).to have_attributes(user_id: user.id, feature: "match_advice", success: true,
                                   prompt_tokens: 10, completion_tokens: 20, total_tokens: 30)
  end

  it "usage が無い場合、トークン数は NULL で記録すること" do
    body = { choices: [{ message: { content: "ok" } }] }.to_json
    with_server(body: body) { expect(call_client).to be_success }
    expect(AiUsageLog.last).to have_attributes(success: true, prompt_tokens: nil, total_tokens: nil)
  end

  it "非2xxは http_error の失敗として返し、例外を投げないこと" do
    with_server(status: 500, body: "{}") do
      result = call_client
      expect(result).not_to be_success
      expect(result.error_kind).to eq("http_error")
    end
    expect(AiUsageLog.last).to have_attributes(success: false, error_kind: "http_error")
  end

  it "contentが空なら empty の失敗になること" do
    body = { choices: [{ message: { content: "  " } }] }.to_json
    with_server(body: body) { expect(call_client.error_kind).to eq("empty") }
  end

  it "不正なJSONは parse の失敗になること" do
    with_server(body: "not json") { expect(call_client.error_kind).to eq("parse") }
  end

  it "応答が遅い場合は timeout の失敗になること" do
    with_server(body: ok_body, delay: 3) do
      result = call_client(timeout: 1)
      expect(result.error_kind).to eq("timeout")
      expect(result.duration_ms).to be < 2500
    end
  end

  it "接続できない場合は network の失敗になること" do
    expect(call_client.error_kind).to eq("network")
  end

  it "APIキーが無い場合は config の失敗になること" do
    allow(ENV).to receive(:fetch).with("OPENAI_API_KEY").and_raise(KeyError)
    expect(call_client.error_kind).to eq("config")
  end

  it "json: true のとき response_format を送ること" do
    captured = nil
    allow_any_instance_of(Net::HTTP::Post).to receive(:body=) { |_req, b| captured = b }
    call_client(json: true)
    expect(JSON.parse(captured)["response_format"]).to eq("type" => "json_object")
  end

  it "ログにプロンプト本文やAPIキーを出さないこと" do
    io = StringIO.new
    allow(Rails).to receive(:logger).and_return(ActiveSupport::Logger.new(io))
    with_server(body: ok_body) do
      described_class.chat(feature: "match_advice", system: "秘密のシステム", user_prompt: "秘密のユーザー文")
    end
    expect(io.string).to include("[OpenaiClient]")
    expect(io.string).not_to include("秘密")
    expect(io.string).not_to include("アドバイス本文")
  end

  it "使用量の記録に失敗してもAI結果を壊さないこと" do
    allow(AiUsageLog).to receive(:create!).and_raise(StandardError)
    with_server(body: ok_body) { expect(call_client).to be_success }
  end
end
