# 試合アドバイスの生成を一手に担う。
# - 有効なアドバイスが既にあれば何もしない（:existing）
# - 同時生成は advice_generating_at の atomic UPDATE で排他（他が生成中なら :busy）
# - 成功時のみ advice を保存（:generated）。失敗時は advice を変更せず advice_failed_at を記録（:failed）
class AdviceGenerator
  CLAIM_TTL = 45.seconds

  def self.call(match_info)
    new(match_info).call
  end

  def initialize(match_info)
    @match_info = match_info
  end

  def call
    return :existing if @match_info.advice_available?
    return resolve_unclaimed unless claim

    begin
      advice = generate
      advice.present? ? save_success(advice) : save_failure
    ensure
      release_claim
    end
  end

  private

  def claim
    now = Time.current
    MatchInfo.where(id: @match_info.id)
      .where(advice: [nil, "", MatchInfo::LEGACY_FAILURE_ADVICE])
      .where("advice_generating_at IS NULL OR advice_generating_at < ?", now - CLAIM_TTL)
      .update_all(advice_generating_at: now).positive? # rubocop:disable Rails/SkipsModelValidations
  end

  # claim できなかった: 他リクエストが生成を完了していれば :existing、生成中なら :busy
  def resolve_unclaimed
    @match_info.reload
    @match_info.advice_available? ? :existing : :busy
  end

  def generate
    if @match_info.serve_receive?
      builder = ServeReceiveContextBuilder.new(@match_info)
      ChatgptService.get_serve_receive_advice(@match_info, builder)
    else
      ChatgptService.get_advice(@match_info)
    end
  rescue StandardError => e
    Rails.logger.error("AdviceGenerator error: #{e.class}")
    nil
  end

  def save_success(advice)
    @match_info.update_columns(advice: advice, advice_failed_at: nil) # rubocop:disable Rails/SkipsModelValidations
    :generated
  end

  def save_failure
    @match_info.update_columns(advice_failed_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    :failed
  end

  def release_claim
    @match_info.update_columns(advice_generating_at: nil) # rubocop:disable Rails/SkipsModelValidations
  end
end
