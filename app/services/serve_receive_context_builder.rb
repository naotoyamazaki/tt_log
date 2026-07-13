class ServeReceiveContextBuilder
  def initialize(match_info)
    @match_info = match_info
    @analyzer = ServeReceiveAnalyzer.new(match_info)
  end

  def build_context
    [
      "【サーブ起点の分析】",
      serve_analysis_text,
      "【レシーブ起点の分析】",
      receive_analysis_text,
      "【得点タイミング】",
      timing_analysis_text
    ].join("\n")
  end

  private

  def serve_analysis_text
    length_lines = @analyzer.serve_length_stats.map do |stat|
      "#{stat[:label]}の得点率は#{stat[:rate]}%（#{stat[:score]}得点/#{stat[:lost_score]}失点）"
    end
    pattern_lines = @analyzer.serve_pattern_stats.first(3).map do |stat|
      "有効パターン: 自分の#{stat[:label]}（自分の3球目攻撃） (#{stat[:score]}得点, 得点率#{stat[:rate]}%)"
    end
    (length_lines + pattern_lines).join("\n")
  end

  def receive_analysis_text
    direct_lines = @analyzer.receive_direct_stats.first(3).map do |stat|
      "#{stat[:label]}の得点率: #{stat[:rate]}%（#{stat[:score]}得点/#{stat[:lost_score]}失点）"
    end
    note_line = "※以下は2球目のみで決着したラリーとは別に、4球目まで続いたラリーの統計です"
    pattern_lines = @analyzer.receive_pattern_stats.first(3).map do |stat|
      "有効パターン: #{stat[:label]} (#{stat[:score]}得点, 得点率#{stat[:rate]}%)"
    end
    (direct_lines + [note_line] + pattern_lines).join("\n")
  end

  def timing_analysis_text
    dist = @analyzer.decided_at_distribution
    lines = ["サーブ起点:"]
    dist[:serve].each { |e| lines << "  #{e[:label]} #{e[:score]}得点/#{e[:lost_score]}失点" }
    lines << "レシーブ起点:"
    dist[:receive].each { |e| lines << "  #{e[:label]} #{e[:score]}得点/#{e[:lost_score]}失点" }
    lines.join("\n")
  end
end
