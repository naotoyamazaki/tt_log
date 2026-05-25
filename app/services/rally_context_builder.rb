class RallyContextBuilder
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

  def initialize(match_info)
    @match_info = match_info
    @rallies = match_info.rallies.includes(:game).order(:game_number, :sequence_number)
    @games_by_number = match_info.games.order(:game_number).index_by(&:game_number)
  end

  def technique_efficiency_text
    sorted_technique_stats
      .map { |name, wins, losses, rate| "#{name}: 得点 #{wins} / 失点 #{losses}（勝率 #{rate}%）" }
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

  def situation_stats_text
    stats = tally_situation_stats
    [
      format_situation("接戦（±2点差）", stats[:close]),
      format_situation("リード時（+3点以上）", stats[:leading]),
      format_situation("ビハインド時（-3点以上）", stats[:trailing]),
      format_situation("デュース（10-10以降）", stats[:deuce])
    ].compact.join("\n")
  end

  def momentum_text
    max_consecutive, recovery_techniques = tally_momentum
    top_recovery = recovery_techniques.sort_by { |_, count| -count }.first(3)
    recovery_text = top_recovery.map { |tech, count| "#{tech}(#{count}回)" }.join(", ")
    recovery_text = "なし" if recovery_text.empty?
    "最大連続失点: #{max_consecutive}本 / 立て直し技術: #{recovery_text}"
  end

  private

  def sorted_technique_stats
    raw = @rallies.group_by(&:batting_style).map { |style, rs| technique_stat(style, rs) }
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

  def tally_situation_stats
    stats = { close: [0, 0], leading: [0, 0], trailing: [0, 0], deuce: [0, 0] }
    @rallies.group_by(&:game_number).each_value do |game_rallies|
      accumulate_situation_stats(stats, game_rallies)
    end
    stats
  end

  def accumulate_situation_stats(stats, game_rallies)
    p_score = 0
    o_score = 0
    game_rallies.sort_by(&:sequence_number).each do |rally|
      situation = classify_situation(p_score, o_score)
      rally.winner == 'player' ? stats[situation][0] += 1 : stats[situation][1] += 1
      rally.winner == 'player' ? p_score += 1 : o_score += 1
    end
  end

  def tally_momentum
    max_consecutive = 0
    recovery_techniques = Hash.new(0)
    @rallies.group_by(&:game_number).each_value do |game_rallies|
      local_max, local_recovery = scan_game_momentum(game_rallies)
      max_consecutive = [max_consecutive, local_max].max
      local_recovery.each { |tech, count| recovery_techniques[tech] += count }
    end
    [max_consecutive, recovery_techniques]
  end

  def scan_game_momentum(game_rallies)
    max_consecutive = 0
    recovery = Hash.new(0)
    local_consecutive = 0
    game_rallies.sort_by(&:sequence_number).each do |rally|
      if rally.winner == 'opponent'
        local_consecutive += 1
        max_consecutive = [max_consecutive, local_consecutive].max
      else
        recovery[style_name(rally.batting_style)] += 1 if local_consecutive >= 2
        local_consecutive = 0
      end
    end
    [max_consecutive, recovery]
  end

  def my_serve?(game, sequence_number)
    seq_idx = sequence_number - 1
    is_initial = seq_idx < 20 ? (seq_idx / 2).even? : seq_idx.even?
    game.first_server == 'player' ? is_initial : !is_initial
  end

  def classify_situation(p_score, o_score)
    diff = p_score - o_score
    return :deuce if p_score >= 10 && o_score >= 10 && diff.abs <= 2
    return :leading if diff >= 3
    return :trailing if diff <= -3

    :close
  end

  def format_situation(label, wins_losses)
    wins, losses = wins_losses
    total = wins + losses
    return nil if total.zero?

    rate = (wins * 100.0 / total).round
    "#{label}: 得点率 #{rate}%（得点 #{wins} / 失点 #{losses}）"
  end

  def win_rate(wins, losses)
    total = wins + losses
    total.positive? ? (wins * 100.0 / total).round : 0
  end

  def style_name(style)
    BATTING_STYLE_NAMES[style.to_s] || style.to_s
  end
end
