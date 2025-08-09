class ChatgptService
  API_URL = "https://api.openai.com/v1/chat/completions".freeze

  def self.get_advice(batting_score_data)
    api_key = ENV.fetch("OPENAI_API_KEY")
    body = generate_request_body(batting_score_data)
    headers = generate_headers(api_key)

    response = nil
    response = send_request(body, headers)
    process_response(response)
  rescue StandardError => e
    handle_error(e, response)
  end

  class << self
    private

    def generate_request_body(batting_score_data)
      messages = [
        { role: "system", content: "あなたは卓球コーチです。" },
        { role: "user", content: generate_user_message(batting_score_data) }
      ]

      {
        model: "gpt-4",
        messages: messages,
        max_tokens: 800,
        temperature: 0.7
      }
    end

    def generate_headers(api_key)
      {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{api_key}"
      }
    end

    def send_request(body, headers)
      uri = URI(API_URL)
      Rails.logger.info("Sending data to ChatGPT API: #{body}")

      Net::HTTP.post(uri, body.to_json, headers)
    end

    def process_response(response)
      Rails.logger.info("ChatGPT API Response: #{response.body}")

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error("ChatGPT API Error: #{response.code} #{response.message}")
        return "アドバイスの取得に失敗しました。"
      end

      parsed_response = JSON.parse(response.body)
      parsed_response.dig("choices", 0, "message", "content")&.strip || "アドバイスの取得に失敗しました。"
    rescue JSON::ParserError => e
      handle_error(e, response)
    end

    def generate_user_message(batting_score_data)
      <<~TEXT
        以下は卓球の1試合で使用した技術ごとの得点数と失点数データです。このデータを基に、次の項目について日本語で簡潔にアドバイスを作成してください。
        なお、フォアプッシュはフォアツッツキ、バックプッシュはバックツッツキと表示してください。

        【得点が多く失点が少ない技術の活用方法】
        【得点が多いが失点も多い技術の改善方法】
        【得点が少なく失点が多い技術の改善方法】
        【使用頻度が低い技術や未使用技術の導入方法】

        データ:
        #{batting_score_data}

        アドバイス:
      TEXT
    end

    def handle_error(error, response = nil)
      Rails.logger.error("ChatGPT API Error: #{error.message}")
      Rails.logger.error("Response that caused error: #{response.body}") if response
      "アドバイスの取得に失敗しました。"
    end
  end
end
