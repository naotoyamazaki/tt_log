# 複数試合を横断して「対戦相手の属性（戦型など）ごとの勝率」を集計するサービス。
# GrowthDashboardAggregator#calculate_share と同様に「件数を数えて割合を出す」パターンを踏襲する。
class OpponentTypeWinRateAggregator
  def initialize(match_infos:, attribute:)
    @match_infos = match_infos
    @attribute = attribute
  end

  # => [{ type_label: "カットマン", match_count: 3, win_count: 2, lose_count: 1, win_rate: 67 }, ...]
  def type_win_rates
    grouped_match_infos.filter_map { |type_key, infos| build_type_entry(type_key, infos) }
  end

  private

  def grouped_match_infos
    @match_infos.group_by { |match_info| match_info.public_send(@attribute) }
  end

  def build_type_entry(type_key, infos)
    return nil if type_key.nil?

    results = infos.filter_map(&:result)
    win_count = results.count(:win)
    lose_count = results.count(:lose)
    return nil if (win_count + lose_count).zero?

    {
      type_label: MatchInfo.human_enum_name(@attribute, type_key),
      match_count: win_count + lose_count,
      win_count: win_count,
      lose_count: lose_count,
      win_rate: calculate_share(win_count, win_count + lose_count)
    }
  end

  def calculate_share(target_count, total_count)
    (target_count.to_f / total_count * 100).round
  end
end
