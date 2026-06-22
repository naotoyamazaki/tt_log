class ServeReceiveAnalyzer
  RECEIVE_STYLE_VALUES_USED = ServeReceivePattern::RECEIVE_STYLE_VALUES

  def initialize(match_info)
    @patterns = match_info.serve_receive_patterns.to_a
    @serve_patterns   = @patterns.select(&:origin_serve?)
    @receive_patterns = @patterns.select(&:origin_receive?)
  end

  # ①サーブ長さ別得点率
  def serve_length_stats
    entries = ServeReceivePattern.serve_lengths.keys.filter_map do |length|
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

  # ③レシーブ技術別得点率
  def receive_style_stats
    entries = RECEIVE_STYLE_VALUES_USED.filter_map do |key, val|
      patterns = @receive_patterns.select { |p| p.receive_style == val }
      next if patterns.empty?

      build_stats(label: Score.human_enum_name(:batting_style, key), patterns: patterns)
    end
    append_share(entries)
  end

  # ④レシーブ（技術+4球目）組み合わせ別
  def receive_pattern_stats
    grouped = @receive_patterns.group_by { |p| [p.receive_style, p.attack_style] }
    mapped = grouped.map do |(recv, attack), patterns|
      recv_label = recv ? Score.human_enum_name(:batting_style, receive_key(recv)) : '不明'
      attack_label_str = attack_label(attack)
      build_stats(label: "#{recv_label} → #{attack_label_str}", patterns: patterns)
    end
    append_share(mapped.sort_by { |s| -s[:score] })
  end

  # ⑤決着タイミング分布（全体・サーブ/レシーブ別）
  def decided_at_distribution
    {
      all: decided_at_group(@patterns),
      serve: decided_at_group(@serve_patterns),
      receive: decided_at_group(@receive_patterns)
    }
  end

  def empty?
    @patterns.empty?
  end

  private

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
    Score.human_enum_name(:batting_style, key)
  end

  def receive_key(val)
    ServeReceivePattern::RECEIVE_STYLE_VALUES.key(val)
  end

  def decided_at_group(patterns)
    ServeReceivePattern.decided_ats.keys.map do |key|
      grp = patterns.select { |p| p.decided_at == key }
      label = I18n.t("activerecord.attributes.serve_receive_pattern.decided_at.#{key}")
      { label: label, score: grp.count(&:won), lost_score: grp.count { |p| !p.won } }
    end
  end
end
