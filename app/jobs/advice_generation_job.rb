class AdviceGenerationJob < ApplicationJob
  queue_as :default

  def perform(match_info_id)
    match_info = MatchInfo.find_by(id: match_info_id)
    return if match_info.nil? || match_info.advice.present?

    batting_scores = match_info.batting_score_data
    Rails.logger.info("非同期でChatGPTに送信: #{batting_scores.to_json}")
    advice = ChatgptService.get_advice(batting_scores.to_json)
    match_info.update_advice(advice)
  rescue StandardError => e
    Rails.logger.error("AdviceGenerationJob Error: #{e.message}")
  end
end
