class ServeReceiveAnalyzer
  RECEIVE_STYLE_VALUES_USED = ServeReceivePattern::RECEIVE_STYLE_VALUES
  RECEIVE_DIRECT_STYLES = %w[receive_ace receive_miss].freeze

  def initialize(match_info)
    @patterns = match_info.serve_receive_patterns.to_a
    @serve_patterns   = @patterns.select(&:origin_serve?)
    @receive_patterns = @patterns.select(&:origin_receive?)
  end

  # ①サーブ長さ別得点率
  def serve_length_stats
    entries = ServeReceivePattern.serve_lengths.keys.reverse.filter_map do |length|
      patterns = @serve_patterns.select { |p| p.serve_length == length }
      next if patterns.empty?

      build_stats(label: serve_length_label(length), patterns: patterns)
    end
    append_share(entries)
  end

  # ②サーブ（長さ+回転+3球目）組み合わせ別
  def serve_pattern_stats
    grouped = @serve_patterns.group_by { |p| [p.serve_length, p.serve_spins.sort, p.attack_style] }
    mapped = grouped.map do |(length, spins, attack), patterns|
      label = "#{serve_length_label(length)} #{spin_labels(spins)} → #{attack_label(attack)}"
      build_stats(label: label, patterns: patterns)
    end
    append_share(mapped.sort_by { |s| -s[:score] })
  end

  # ③レシーブ直接決着率（レシーブエース・ミスで即決した得点/失点を集計）
  def receive_direct_stats
    direct = @receive_patterns.select { |p| p.attack_style == 'receive_ace' || p.attack_style == 'receive_miss' }
    entries = direct.group_by(&:receive_style).filter_map { |s, p| build_direct_entry(s, p) }
    append_share(entries.sort_by { |s| -s[:score] })
  end

  # ④レシーブ（技術+4球目）組み合わせ別
  def receive_pattern_stats
    grouped = @receive_patterns.group_by { |p| [p.receive_style, p.attack_style] }
    mapped = grouped.map do |(recv, attack), patterns|
      recv_key = recv ? receive_key(recv) : nil
      recv_label = recv_key ? Score.human_enum_name(:batting_style, recv_key) : '不明'
      attack_label_str = attack_label(attack)
      build_stats(label: "#{recv_label} → #{attack_label_str}", patterns: patterns)
    end
    append_share(mapped.sort_by { |s| -s[:score] })
  end

  # ⑤得点タイミング分布（サーブ/レシーブ別）
  def decided_at_distribution
    {
      serve: serve_timing_stats,
      receive: receive_timing_stats
    }
  end

  def empty?
    @patterns.empty?
  end

  private

  def serve_timing_stats
    service_ace_grp = @serve_patterns.select { |p| p.attack_style == 'service_ace' }
    regular = @serve_patterns.reject { |p| p.attack_style == 'service_ace' }
    prefix = service_ace_grp.any? ? [build_timing_entry('1球目', service_ace_grp)] : []
    prefix + timing_entries_for(regular, :serve)
  end

  def receive_timing_stats
    direct_grp = @receive_patterns.select { |p| RECEIVE_DIRECT_STYLES.include?(p.attack_style) }
    regular = @receive_patterns.reject { |p| RECEIVE_DIRECT_STYLES.include?(p.attack_style) }
    prefix = direct_grp.any? ? [build_timing_entry('2球目', direct_grp)] : []
    prefix + timing_entries_for(regular, :receive)
  end

  def timing_entries_for(patterns, origin)
    scope = "activerecord.attributes.serve_receive_pattern.decided_at_#{origin}"
    ServeReceivePattern.decided_ats.each_key.map do |key|
      build_timing_entry(I18n.t("#{scope}.#{key}"), patterns.select { |p| p.decided_at == key })
    end
  end

  def build_timing_entry(label, patterns)
    score = patterns.count(&:won)
    lost_score = patterns.count { |p| !p.won }
    total = score + lost_score
    rate = total.positive? ? (score.to_f / total * 100).round : 0
    { label: label, score: score, lost_score: lost_score, rate: rate, share: 0 }
  end

  def build_stats(label:, patterns:)
    score      = patterns.count(&:won)
    lost_score = patterns.count { |p| !p.won }
    total      = score + lost_score
    rate       = total.positive? ? (score.to_f / total * 100).round : 0
    { label: label, score: score, lost_score: lost_score, rate: rate, share: 0 }
  end

  def append_share(entries)
    total = entries.sum { |e| e[:score] }
    entries.map do |e|
      share = total.positive? ? (e[:score].to_f / total * 100).round : 0
      e.merge(share: share)
    end
  end

  def serve_length_label(key)
    I18n.t("activerecord.attributes.serve_receive_pattern.serve_length.#{key}")
  end

  def spin_labels(spins)
    spins.map { |i| ServeReceivePattern::SERVE_SPIN_NAMES_JA[i] }.join('+')
  end

  def attack_label(key)
    I18n.t("activerecord.attributes.score.batting_style.#{key}",
           default: I18n.t("activerecord.attributes.serve_receive_pattern.attack_style.#{key}", default: key.to_s))
  end

  def receive_key(val)
    ServeReceivePattern::RECEIVE_STYLE_VALUES.key(val)
  end

  def build_direct_entry(recv_style, patterns)
    return unless recv_style

    key = receive_key(recv_style)
    return unless key

    build_stats(label: Score.human_enum_name(:batting_style, key), patterns: patterns)
  end
end
