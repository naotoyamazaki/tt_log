require "net/http"
require "json"

# OpenAI Chat Completions の薄いクライアント。
# - 例外は投げず Result を返す（自動リトライなし）
# - 全体デッドライン（DEADLINE秒）を超えたら timeout として失敗扱い
# - ログにはステータス・処理時間・トークン数のみ出力（プロンプト・本文・APIキーは出さない）
class OpenaiClient
  DEFAULT_API_URL = "https://api.openai.com/v1/chat/completions".freeze
  MODEL = "gpt-5.4-mini".freeze
  OPEN_TIMEOUT = 3
  WRITE_TIMEOUT = 5
  DEADLINE = 24
  NETWORK_ERRORS = [
    SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError, Net::ProtocolError, EOFError
  ].freeze

  Result = Struct.new(:content, :error_kind, :usage, :duration_ms, keyword_init: true) do
    def success?
      error_kind.nil?
    end
  end

  class DeadlineExceeded < StandardError; end

  def self.chat(**)
    new(**).chat
  end

  def initialize(feature:, system:, user_prompt:, json: false, max_completion_tokens: 2500, # rubocop:disable Metrics/ParameterLists
                 temperature: nil, timeout: 20, user: nil, match_info: nil)
    @feature = feature
    @system = system
    @user_prompt = user_prompt
    @json = json
    @max_completion_tokens = max_completion_tokens
    @temperature = temperature
    @timeout = timeout
    @user = user
    @match_info = match_info
  end

  def chat
    @started_at = monotonic_now
    result = perform_request
    record_usage(result)
    log_result(result)
    result
  end

  private

  def perform_request
    response_body = post_request
    parse_response(response_body)
  rescue DeadlineExceeded, Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout
    build_result(error_kind: "timeout")
  rescue *NETWORK_ERRORS
    build_result(error_kind: "network")
  rescue KeyError
    build_result(error_kind: "config")
  rescue StandardError
    build_result(error_kind: "unknown")
  end

  def post_request
    uri = URI(ENV.fetch("OPENAI_API_URL", DEFAULT_API_URL))
    request = build_request(uri) # 接続前に生成（APIキー欠落を network 失敗と区別する）
    http = build_http(uri)
    @status = nil
    body = http.start { read_response(http, request) }
    raise DeadlineExceeded if remaining_time <= 0

    body
  end

  # チャンクごとに残り時間で read_timeout を絞り、全体デッドラインを超えさせない
  def read_response(http, request)
    body = +""
    http.request(request) do |res|
      @status = res.code.to_i
      res.read_body do |chunk|
        body << chunk
        http.read_timeout = [remaining_time, 0.1].max
      end
    end
    body
  end

  def build_http(uri)
    Net::HTTP.new(uri.host, uri.port).tap do |http|
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = OPEN_TIMEOUT
      http.write_timeout = WRITE_TIMEOUT
      http.read_timeout = [@timeout, remaining_time].min
    end
  end

  def build_request(uri)
    Net::HTTP::Post.new(uri, "Content-Type" => "application/json",
                             "Authorization" => "Bearer #{ENV.fetch('OPENAI_API_KEY')}").tap do |req|
      req.body = request_body.to_json
    end
  end

  def request_body
    body = {
      model: MODEL,
      messages: [{ role: "system", content: @system }, { role: "user", content: @user_prompt }],
      max_completion_tokens: @max_completion_tokens
    }
    body[:temperature] = @temperature if @temperature
    body[:response_format] = { type: "json_object" } if @json
    body
  end

  def parse_response(body)
    return build_result(error_kind: "http_error") unless (200..299).cover?(@status)

    parsed = JSON.parse(body)
    content = parsed.dig("choices", 0, "message", "content").to_s.strip
    usage = parsed["usage"]
    return build_result(error_kind: "empty", usage: usage) if content.empty?

    build_result(content: content, usage: usage)
  rescue JSON::ParserError
    build_result(error_kind: "parse")
  end

  def build_result(content: nil, error_kind: nil, usage: nil)
    Result.new(content: content, error_kind: error_kind, usage: usage, duration_ms: elapsed_ms)
  end

  def record_usage(result)
    usage = result.usage.is_a?(Hash) ? result.usage : {}
    AiUsageLog.create!(
      user_id: @user&.id, match_info_id: @match_info&.id, feature: @feature, model: MODEL,
      success: result.success?, error_kind: result.error_kind, duration_ms: result.duration_ms,
      prompt_tokens: usage["prompt_tokens"], completion_tokens: usage["completion_tokens"],
      total_tokens: usage["total_tokens"]
    )
  rescue StandardError => e
    Rails.logger.error("AiUsageLog record failed: #{e.class}")
  end

  def log_result(result)
    tokens = result.usage.is_a?(Hash) ? result.usage["total_tokens"] : nil
    Rails.logger.info(
      "[OpenaiClient] feature=#{@feature} status=#{@status.inspect} success=#{result.success?} " \
      "error_kind=#{result.error_kind.inspect} duration_ms=#{result.duration_ms} total_tokens=#{tokens.inspect}"
    )
  end

  def remaining_time
    DEADLINE - (monotonic_now - @started_at)
  end

  def elapsed_ms
    ((monotonic_now - @started_at) * 1000).round
  end

  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
