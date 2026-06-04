class RallyContextBuilder # rubocop:disable Metrics/ClassLength
  NET_OR_EDGE_STYLE = 'net_or_edge'.freeze

  BATTING_STYLE_NAMES = {
    'serve' => 'サーブ',
    'receive' => 'レシーブ',
    'fore_drive_vs_topspin' => '対上回転フォアドライブ',
    'back_drive_vs_topspin' => '対上回転バックドライブ',
    'fore_drive_vs_backspin' => '対下回転フォアドライブ',
    'back_drive_vs_backspin' => '対下回転バックドライブ',
    'fore_push' => 'フォアツッツキ',
    'back_push' => 'バックツッツキ',
    'fore_stop' => 'フォアストップ',
    'back_stop' => 'バックストップ',
    'fore_flick' => 'フォアフリック',
    'back_flick' => 'バックフリック',
    'chiquita' => 'チキータ',
    'fore_block' => 'フォアブロック',
    'back_block' => 'バックブロック',
    'fore_counter' => 'フォアカウンター',
    'back_counter' => 'バックカウンター',
    'fore_smash' => 'フォアスマッシュ',
    'back_smash' => 'バックスマッシュ',
    'net_or_edge' => 'ネットorエッジ'
  }.freeze

  SITUATION_KEYS = %i[tied close_one close_two leading trailing deuce].freeze

  def initialize(match_info)
    @match_info = match_info
    @rallies = match_info.rallies.includes(:game).order(:game_number, :sequence_number)
    @games_by_number = match_info.games.order(:game_number).index_by(&:game_number)
  end

  def technique_efficiency_text
    sorted_technique_stats
      .map { |name, wins, losses, rate| "#{name}: 自分得点 #{wins} / 相手得点 #{losses}（自分の得点率 #{rate}%）" }
      .join("\n")
  end

  def serve_situation_text
    counts = tally_serve_situations
    my_rate = win_rate(counts[:my_wins], counts[:my_losses])
    opp_rate = win_rate(counts[:opp_wins], counts[:opp_losses])
    [
      "自分のサーブ時: 得点率 #{my_rate}%（得点 #{counts[:my_wins]} / 失点 #{counts[:my_losses]}）",
      "相手のサーブ時: 得点率 #{opp_rate}%（得点 #{counts[:opp_wins]} / 失点 #{counts[:opp_losses]}）"
    ].join("\n")
  end

  def game_flow_text
    lines = []
    @rallies.group_by(&:game_number).each do |game_num, game_rallies|
      game = @games_by_number[game_num]
      next unless game

      result_label = game.player_score > game.opponent_score ? "勝ち" : "負け"
      lines << "第#{game_num}ゲーム（#{game.player_score}-#{game.opponent_score} #{result_label}）:"
      lines << build_game_technique_line(game_rallies, 'player', '自分の得点技術')
      lines << build_game_technique_line(game_rallies, 'opponent', '相手の得点技術')
    end
    lines.join("\n")
  end

  def situation_stats_text
    stats = tally_granular_situation_stats
    [
      format_granular_situation("同点時", stats[:tied]),
      format_granular_situation("±1点差（接戦）", stats[:close_one]),
      format_granular_situation("±2点差（接戦）", stats[:close_two]),
      format_granular_situation("リード時（+3点以上）", stats[:leading]),
      format_granular_situation("ビハインド時（-3点以上）", stats[:trailing]),
      format_granular_situation("デュース（10-10以降）", stats[:deuce])
    ].compact.join("\n")
  end

  def streak_and_pattern_text
    win_max, win_stoppers = streak_data('player')
    loss_max, loss_recoverers = streak_data('opponent')
    [
      "最大連続得点: #{win_max}本 / 止まった要因技術: #{format_tech_list(win_stoppers)}",
      "最大連続失点: #{loss_max}本 / 立て直し技術: #{format_tech_list(loss_recoverers)}",
      "ゲームパターン: #{game_result_patterns}"
    ].join("\n")
  end

  private

  def sorted_technique_stats
    raw = @rallies.group_by(&:batting_style)
      .reject { |style, _| style.to_s == NET_OR_EDGE_STYLE }
      .map { |style, rs| technique_stat(style, rs) }
    raw.sort_by { |_, _, _, rate| -rate }
  end

  def technique_stat(style, rallies)
    wins = rallies.count { |r| r.winner == 'player' }
    losses = rallies.count { |r| r.winner == 'opponent' }
    rate = rallies.size.positive? ? (wins * 100.0 / rallies.size).round : 0
    [style_name(style), wins, losses, rate]
  end

  def tally_serve_situations
    counts = { my_wins: 0, my_losses: 0, opp_wins: 0, opp_losses: 0 }
    @rallies.each do |rally|
      game = @games_by_number[rally.game_number]
      next unless game&.first_server

      add_serve_count(counts, rally, my_serve?(game, rally.sequence_number))
    end
    counts
  end

  def add_serve_count(counts, rally, my_serve)
    if my_serve
      rally.winner == 'player' ? counts[:my_wins] += 1 : counts[:my_losses] += 1
    else
      rally.winner == 'player' ? counts[:opp_wins] += 1 : counts[:opp_losses] += 1
    end
  end

  def build_game_technique_line(game_rallies, winner_side, label)
    top = technique_top3(game_rallies, winner_side)
    return "  #{label}: なし" if top.empty?

    "  #{label}: #{top.map { |n, c| "#{n}(#{c})" }.join(', ')}"
  end

  def technique_top3(game_rallies, winner_side)
    game_rallies
      .select { |r| r.winner == winner_side && r.batting_style.to_s != NET_OR_EDGE_STYLE }
      .group_by(&:batting_style)
      .map { |s, rs| [style_name(s), rs.size] }
      .sort_by { |_, n| -n }
      .first(3)
  end

  def tally_granular_situation_stats
    stats = SITUATION_KEYS.index_with { [0, 0, Hash.new(0)] }
    @rallies.group_by(&:game_number).each_value do |game_rallies|
      accumulate_granular_situation_stats(stats, game_rallies)
    end
    stats
  end

  def accumulate_granular_situation_stats(stats, game_rallies) # rubocop:disable Metrics/AbcSize
    p_score = 0
    o_score = 0
    game_rallies.sort_by(&:sequence_number).each do |rally|
      situation = classify_granular_situation(p_score, o_score)
      if rally.winner == 'player'
        stats[situation][0] += 1
        stats[situation][2][style_name(rally.batting_style)] += 1 unless rally.batting_style.to_s == NET_OR_EDGE_STYLE
      else
        stats[situation][1] += 1
      end
      rally.winner == 'player' ? p_score += 1 : o_score += 1
    end
  end

  def classify_granular_situation(p_score, o_score) # rubocop:disable Metrics/CyclomaticComplexity
    diff = p_score - o_score
    return :deuce if p_score >= 10 && o_score >= 10 && diff.abs <= 2
    return :leading if diff >= 3
    return :trailing if diff <= -3
    return :tied if diff.zero?
    return :close_one if diff.abs == 1

    :close_two
  end

  def format_granular_situation(label, data)
    wins, losses, techniques = data
    total = wins + losses
    return nil if total.zero?

    rate = (wins * 100.0 / total).round
    top_tech = techniques.sort_by { |_, c| -c }.first(2).map { |n, c| "#{n}(#{c}点)" }.join(', ')
    tech_suffix = top_tech.present? ? " / 得点技術: #{top_tech}" : ""
    "#{label}: 得点率 #{rate}%（得点 #{wins} / 失点 #{losses}）#{tech_suffix}"
  end

  def streak_data(streak_winner)
    max_streak = 0
    breakers = Hash.new(0)
    @rallies.group_by(&:game_number).each_value do |game_rallies|
      local_max, local_breakers = scan_streak(game_rallies, streak_winner)
      max_streak = [max_streak, local_max].max
      local_breakers.each { |tech, count| breakers[tech] += count }
    end
    [max_streak, breakers]
  end

  def scan_streak(game_rallies, streak_winner)
    max_streak = 0
    breakers = Hash.new(0)
    local_streak = 0
    game_rallies.sort_by(&:sequence_number).each do |rally|
      if rally.winner == streak_winner
        local_streak += 1
        max_streak = [max_streak, local_streak].max
      else
        if local_streak >= 2 && rally.batting_style.to_s != NET_OR_EDGE_STYLE
          breakers[style_name(rally.batting_style)] += 1
        end
        local_streak = 0
      end
    end
    [max_streak, breakers]
  end

  def game_result_patterns
    counts = { leading_wins: 0, comeback_wins: 0, blown_losses: 0, trailing_losses: 0 }
    @rallies.group_by(&:game_number).each do |game_num, game_rallies|
      game = @games_by_number[game_num]
      next unless game

      classify_game_pattern(counts, game, game_rallies)
    end
    format_game_patterns(counts)
  end

  def classify_game_pattern(counts, game, game_rallies) # rubocop:disable Metrics/AbcSize
    player_won = game.player_score > game.opponent_score
    was_trailing = false
    was_leading = false
    p_score = 0
    o_score = 0
    game_rallies.sort_by(&:sequence_number).each do |rally|
      diff = p_score - o_score
      was_leading = true if diff >= 3
      was_trailing = true if diff <= -3
      rally.winner == 'player' ? p_score += 1 : o_score += 1
    end
    key = game_pattern_key(player_won, was_trailing, was_leading)
    counts[key] += 1
  end

  def game_pattern_key(player_won, was_trailing, was_leading)
    if player_won
      was_trailing ? :comeback_wins : :leading_wins
    else
      was_leading ? :blown_losses : :trailing_losses
    end
  end

  PATTERN_LABELS = {
    leading_wins: "先行逃げ切り",
    comeback_wins: "逆転勝ち",
    blown_losses: "リード逃し",
    trailing_losses: "ビハインド負け"
  }.freeze

  def format_game_patterns(counts)
    parts = PATTERN_LABELS.filter_map do |key, label|
      "#{label}#{counts[key]}ゲーム" if counts[key].positive?
    end
    parts.empty? ? "データなし" : parts.join(" / ")
  end

  def format_tech_list(tech_hash)
    top = tech_hash.sort_by { |_, c| -c }.first(3)
    top.empty? ? "なし" : top.map { |n, c| "#{n}(#{c}回)" }.join(', ')
  end

  def my_serve?(game, sequence_number)
    seq_idx = sequence_number - 1
    is_initial = seq_idx < 20 ? (seq_idx / 2).even? : seq_idx.even?
    game.first_server == 'player' ? is_initial : !is_initial
  end

  def win_rate(wins, losses)
    total = wins + losses
    total.positive? ? (wins * 100.0 / total).round : 0
  end

  def style_name(style)
    BATTING_STYLE_NAMES[style.to_s] || style.to_s
  end
end
