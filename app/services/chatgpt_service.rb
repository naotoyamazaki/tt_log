# app/services/chatgpt_service.rb
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
        content: "以下は卓球の技術ごとの得点率データです。このデータをもとに、選手がどの技術を強化すべきか、改善すべき点を含めたアドバイスを日本語で簡潔に作成してください。なお、フォアハンドプッシュとバックハンドプッシュのプッシュの部分はツッツキと表示してください。\n\nデータ: #{batting_score_data}\n\nアドバイス:"
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
      # リクエストデータのログ
      Rails.logger.info("Sending data to ChatGPT API: #{body}")

      response = Net::HTTP.post(uri, body.to_json, headers)

      # レスポンス内容のログ
      Rails.logger.info("ChatGPT API Response: #{response.body}")

      # レスポンスのステータスコードを確認
      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error("ChatGPT API Error: #{response.code} #{response.message}")
        return "アドバイスの取得に失敗しました。"
      end

      parsed_response = JSON.parse(response.body)

      # choicesキーの存在を確認
      if parsed_response["choices"] && parsed_response["choices"][0] && parsed_response["choices"][0]["message"]["content"]
        return parsed_response["choices"][0]["message"]["content"].strip
      else
        Rails.logger.error("ChatGPT API Response Format Error: #{response.body}")
        return "アドバイスの取得に失敗しました。"
      end
    rescue JSON::ParserError => e
      Rails.logger.error("JSON Parsing Error: #{e.message}")
      Rails.logger.error("Response that caused error: #{response.body}") if response
      "アドバイスの取得に失敗しました。"
    rescue StandardError => e
      Rails.logger.error("ChatGPT API Unknown Error: #{e.message}")
      raise # 必要に応じて例外を再スロー
    end
  end
end
