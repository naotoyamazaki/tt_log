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
    'net_or_edge' => { abbr: 'N/E', label: 'ネット/エッジ' }
  }.freeze

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

  private

  def build_aggregated_score_data(batting_style, scores)
    total_score = scores.sum(&:score)
    total_lost = scores.sum(&:lost_score)
    total = total_score + total_lost
    rate = total.positive? ? (total_score.to_f / total * 100).round : 0
    { batting_style: batting_style, rate: rate, score: total_score, lost_score: total_lost }
  end
end
