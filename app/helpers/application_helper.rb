module ApplicationHelper
  include Pagy::Frontend

  BATTING_STYLE_ABBR_MAP = {
    'serve' => { abbr: 'S', label: 'サーブ' },
    'receive' => { abbr: 'R', label: 'レシーブ' },
    'fore_drive_vs_topspin' => { abbr: 'FD+', label: 'フォアドライブ(対上)' },
    'back_drive_vs_topspin' => { abbr: 'BD+', label: 'バックドライブ(対上)' },
    'fore_drive_vs_backspin' => { abbr: 'FD-', label: 'フォアドライブ(対下)' },
    'back_drive_vs_backspin' => { abbr: 'BD-', label: 'バックドライブ(対下)' },
    'fore_push' => { abbr: 'FP', abbr_ja: 'FT', label: 'フォアツッツキ' },
    'back_push' => { abbr: 'BP', abbr_ja: 'BT', label: 'バックツッツキ' },
    'fore_stop' => { abbr: 'FS',  label: 'フォアストップ' },
    'back_stop' => { abbr: 'BS',  label: 'バックストップ' },
    'fore_flick' => { abbr: 'FF',  label: 'フォアフリック' },
    'back_flick' => { abbr: 'BF',  label: 'バックフリック' },
    'chiquita' => { abbr: 'C', label: 'チキータ' },
    'fore_block' => { abbr: 'FB', label: 'フォアブロック' },
    'back_block' => { abbr: 'BB', label: 'バックブロック' },
    'fore_counter' => { abbr: 'FC',  label: 'フォアカウンター' },
    'back_counter' => { abbr: 'BC',  label: 'バックカウンター' },
    'fore_smash' => { abbr: 'FSm', label: 'フォアスマッシュ' },
    'back_smash' => { abbr: 'BSm', label: 'バックスマッシュ' },
    'net_or_edge' => { abbr: 'N/E', label: 'ネット/エッジ' },
    'lobbing' => { abbr: 'Lob', label: 'ロビング' },
    'serve_miss' => { abbr: 'SM', label: 'サーブミス' }
  }.freeze

  SHARE_HELP_TEXTS = {
    player: '自分の得点のうち、その技術で取った点の割合です',
    opponent: '相手の得点（好プレー）のうち、その技術で取られた点の割合です。自分の凡ミスは含みません',
    own_error: '自分の凡ミス全体のうち、その技術でのミスの割合です。その技術を使った回数に対するミス率ではありません'
  }.freeze

  # ランキング表の割合列の見出しに付ける「?」ボタン（タップで説明を表示）
  def share_help_button(theme)
    text = SHARE_HELP_TEXTS[theme]
    return if text.blank?

    tag.button('?', type: 'button', class: 'share-help-btn', 'aria-label': '数値の説明',
                    data: { tap_tooltip: text, tap_tooltip_sticky: 'true' })
  end

  def batting_style_abbr_info(style_key)
    BATTING_STYLE_ABBR_MAP[style_key] || { abbr: style_key, label: style_key }
  end

  def abbreviate_batting_style(name)
    name.gsub('フォア', 'F').gsub('バック', 'B')
      .gsub('対上回転', '対上').gsub('対下回転', '対下')
  end

  def calculate_batting_score_data(batting_scores)
    aggregated = batting_scores.group_by(&:batting_style).map do |batting_style, scores|
      build_aggregated_score_data(batting_style, scores)
    end
    aggregated.sort_by { |entry| [-entry[:rate], -(entry[:score] + entry[:lost_score])] }
  end

  def player_scoring_techniques(batting_scores)
    entries = aggregate_entries(batting_scores, :build_aggregated_score_data)
      .reject { |e| e[:score].zero? }
      .sort_by { |e| [-e[:score], -e[:lost_score]] }
    append_share(entries, :score)
  end

  def opponent_scoring_techniques(batting_scores)
    entries = aggregate_entries(batting_scores, :build_opponent_score_data)
      .reject { |e| e[:lost_score].zero? }
      .sort_by { |e| [-e[:lost_score], -e[:score]] }
    append_share(entries, :lost_score)
  end

  # 自分の凡ミス技術ランキング（ミス数降順、同数は技術の固定順）。
  # 使用回数が不明なためミス率は出さず、全凡ミスに占める割合(share)のみ返す。
  def own_error_techniques(batting_scores)
    order = BATTING_STYLE_ABBR_MAP.keys
    entries = batting_scores.group_by(&:batting_style).map do |batting_style, scores|
      { batting_style: batting_style, own_error_count: scores.sum(&:own_error_count) }
    end
    entries = entries.reject { |e| e[:own_error_count].zero? }
      .sort_by { |e| [-e[:own_error_count], order.index(e[:batting_style]) || order.size] }
    append_share(entries, :own_error_count)
  end

  private

  def aggregate_entries(batting_scores, builder)
    batting_scores.group_by(&:batting_style).map do |batting_style, scores|
      send(builder, batting_style, scores)
    end
  end

  def append_share(entries, score_key)
    total = entries.sum { |e| e[score_key] }
    entries.map do |e|
      share = total.positive? ? (e[score_key].to_f / total * 100).round : 0
      e.merge(share: share)
    end
  end

  def build_aggregated_score_data(batting_style, scores)
    total_score = scores.sum(&:score)
    total_lost = scores.sum(&:lost_score)
    total = total_score + total_lost
    rate = total.positive? ? (total_score.to_f / total * 100).round : 0
    { batting_style: batting_style, rate: rate, score: total_score, lost_score: total_lost }
  end

  def build_opponent_score_data(batting_style, scores)
    data = build_aggregated_score_data(batting_style, scores)
    total = data[:score] + data[:lost_score]
    opponent_rate = total.positive? ? (data[:lost_score].to_f / total * 100).round : 0
    data.merge(opponent_rate: opponent_rate)
  end
end
