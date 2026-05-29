class ChatgptService
  API_URL = "https://api.openai.com/v1/chat/completions".freeze

  def self.get_advice(match_info)
    api_key = ENV.fetch("OPENAI_API_KEY")
    body = generate_request_body(match_info)
    headers = generate_headers(api_key)

    response = nil
    response = send_request(body, headers)
    process_response(response)
  rescue StandardError => e
    handle_error(e, response)
  end

  class << self
    private

    def generate_request_body(match_info)
      messages = [
        { role: "system", content: system_prompt },
        { role: "user", content: generate_user_message(match_info) }
      ]

      {
        model: "gpt-5.4-mini",
        messages: messages,
        max_completion_tokens: 2500,
        temperature: 0.7
      }
    end

    def system_prompt
      "あなたは経験豊富な卓球コーチです。\n" \
        "提供されるデータは実際の試合を1ラリーずつ記録したものです。\n" \
        "データを深く分析し、選手が次の練習・試合で即座に実践できる具体的なアドバイスを作成してください。\n" \
        "なお、ネットorエッジはラッキー・アンラッキーな偶発的ポイントであるため、アドバイスの内容には含めないでください。\n" \
        "6項目のアドバイスを出力したら必ず終了してください。追加提案や続きを促す文言は一切出力しないでください。"
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

    def generate_user_message(match_info)
      if match_info.rallies.any?
        rally_based_message(match_info)
      else
        legacy_message(match_info)
      end
    end

    def rally_based_message(match_info)
      builder = RallyContextBuilder.new(match_info)
      game_score_text = build_game_score_text(match_info)

      <<~TEXT
        以下は卓球の試合データです。日本語で6項目のアドバイスを作成してください。
        なお、フォアプッシュはフォアツッツキ、バックプッシュはバックツッツキと表示してください。

        【試合結果】
        #{match_info.game_count_score}（ゲームスコア: #{game_score_text}）

        #{rally_stats_text(builder)}

        #{advice_format_instruction}

        アドバイス:
      TEXT
    end

    def rally_stats_text(builder)
      <<~TEXT.chomp
        【技術別得点効率（高勝率→低勝率）】
        #{builder.technique_efficiency_text}

        【サーブ・レシーブ局面分析】
        #{builder.serve_situation_text}

        【ゲームごとの技術の流れ】
        #{builder.game_flow_text}

        【得点/失点ラッシュと試合パターン】
        #{builder.streak_and_pattern_text}

        【スコア状況別分析（接戦・デュース）】
        #{builder.situation_stats_text}
      TEXT
    end

    def advice_format_instruction
      <<~TEXT.chomp
        以下の6項目について、具体的なアドバイスを作成してください。
        各項目は必ず下記のフォーマットで出力し、項目と項目の間は必ず1行空けてください:
        1.【サーブ戦術の改善】アドバイス文
        2.【レシーブ戦術の改善】アドバイス文
        3.【得意技術の活用戦略】アドバイス文
        4.【弱点技術の改善方法】アドバイス文
        5.【試合の流れ・ラッシュへの対処法】アドバイス文
        6.【接戦・デュースで勝ち切るための技術選択】アドバイス文
      TEXT
    end

    def build_game_score_text(match_info)
      match_info.games.order(:game_number).map do |g|
        "#{g.player_score}-#{g.opponent_score}"
      end.join(", ")
    end

    def legacy_message(match_info)
      batting_score_data = match_info.batting_score_data.to_json
      game_data = match_info.game_by_game_score_data
      game_section = build_game_section(game_data)

      <<~TEXT
        以下は卓球の1試合で使用した技術ごとの得点数と失点数データです。このデータを基に、次の項目について日本語で簡潔にアドバイスを作成してください。
        なお、フォアプッシュはフォアツッツキ、バックプッシュはバックツッツキと表示してください。

        【得点が多く失点が少ない技術の活用方法】
        【得点が多いが失点も多い技術の改善方法】
        【得点が少なく失点が多い技術の改善方法】
        【使用頻度が低い技術や未使用技術の導入方法】
        #{game_section.present? ? '【ゲームごとの傾向と流れの分析】' : ''}

        データ:
        #{batting_score_data}
        #{game_section}
        アドバイス:
      TEXT
    end

    def build_game_section(game_data)
      return "" if game_data.blank?

      lines = ["\nゲーム別データ:"]
      game_data.each do |game|
        lines << "第#{game[:game_number]}ゲーム（#{game[:score]}、#{game[:result]}）:"
        game[:techniques].each { |t| lines << "  #{t}" }
      end
      lines.join("\n")
    end

    def handle_error(error, response = nil)
      Rails.logger.error("ChatGPT API Error: #{error.message}")
      Rails.logger.error("Response that caused error: #{response.body}") if response
      "アドバイスの取得に失敗しました。"
    end
  end
end
