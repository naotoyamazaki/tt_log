require 'net/http'
require 'json'

class ChatgptService
  def self.get_advice(batting_score_data)
    uri = URI("https://api.openai.com/v1/chat/completions")
    api_key = ENV["OPENAI_API_KEY"]
    messages = [
      {
        role: "system",
        content: "あなたは卓球コーチです。"
      },
      {
        role: "user",
        content: <<~TEXT
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
      }
    ]
    body = {
      model: "gpt-4",
      messages: messages,
      max_tokens: 800,
      temperature: 0.7
    }

    headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer #{api_key}"
    }

    begin
      Rails.logger.info("Sending data to ChatGPT API: #{body}")
      response = Net::HTTP.post(uri, body.to_json, headers)
      Rails.logger.info("ChatGPT API Response: #{response.body}")

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error("ChatGPT API Error: #{response.code} #{response.message}")
        return "アドバイスの取得に失敗しました。"
      end

      parsed_response = JSON.parse(response.body)
      if parsed_response.dig("choices", 0, "message", "content")
        parsed_response.dig("choices", 0, "message", "content").strip
      else
        Rails.logger.error("ChatGPT API Response Format Error: #{response.body}")
        "アドバイスの取得に失敗しました。"
      end
    rescue JSON::ParserError => e
      Rails.logger.error("JSON Parsing Error: #{e.message}")
      Rails.logger.error("Response that caused error: #{response.body}") if response
      "アドバイスの取得に失敗しました。"
    rescue StandardError => e
      Rails.logger.error("ChatGPT API Unknown Error: #{e.message}")
      raise
    end
  end
end
