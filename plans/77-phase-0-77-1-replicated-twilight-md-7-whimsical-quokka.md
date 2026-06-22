# Sprint 3 — サーブ・レシーブ専用分析ページ

## Context

Sprint 1でデータ基盤、Sprint 2で入力フローを実装済み。保存された `ServeReceivePattern` レコードを集計・可視化する「専用分析ページ」を実装する。既存の `show.html.erb` に `analysis_type` 分岐を追加し、5軸の集計表を表示する。

---

## ブランチ

`feature/sprint-3-serve-receive-analysis`

---

## 実装ステップ

### Step 1: `ServeReceiveAnalyzer` サービス新規作成

**ファイル**: `app/services/serve_receive_analyzer.rb`

`RallyContextBuilder` の構造（initialize → private キャッシュ → 公開メソッドで整形済みデータ返却）を参考にする。

```ruby
class ServeReceiveAnalyzer
  def initialize(match_info)
    @patterns = match_info.serve_receive_patterns.to_a
    @serve_patterns  = @patterns.select(&:origin_serve?)
    @receive_patterns = @patterns.select(&:origin_receive?)
  end

  # ①サーブ長さ別得点率
  def serve_length_stats
    ServeReceivePattern.serve_lengths.keys.filter_map do |length|
      patterns = @serve_patterns.select { |p| p.serve_length == length }
      next if patterns.empty?
      build_stats(label: serve_length_label(length), patterns:)
    end.then { append_share(_1) }
  end

  # ②サーブ（長さ+回転+3球目）組み合わせ別
  def serve_pattern_stats
    @serve_patterns
      .group_by { |p| [p.serve_length, p.serve_spins.sort, p.attack_style] }
      .map do |(length, spins, attack), patterns|
        label = "#{serve_length_label(length)} #{spin_labels(spins)} → #{attack_label(attack)}"
        build_stats(label:, patterns:)
      end
      .sort_by { |s| -s[:score] }
      .then { append_share(_1) }
  end

  # ③レシーブ技術別得点率
  def receive_style_stats
    RECEIVE_STYLE_VALUES_USED.filter_map do |key, val|
      patterns = @receive_patterns.select { |p| p.receive_style == val }
      next if patterns.empty?
      build_stats(label: Score.human_enum_name(:batting_style, key), patterns:)
    end.then { append_share(_1) }
  end

  # ④レシーブ（技術+4球目）組み合わせ別
  def receive_pattern_stats
    @receive_patterns
      .group_by { |p| [p.receive_style, p.attack_style] }
      .map do |(recv, attack), patterns|
        recv_label  = recv  ? Score.human_enum_name(:batting_style, receive_key(recv))  : '不明'
        attack_label_str = attack_label(attack)
        build_stats(label: "#{recv_label} → #{attack_label_str}", patterns:)
      end
      .sort_by { |s| -s[:score] }
      .then { append_share(_1) }
  end

  # ⑤決着タイミング分布（全体・サーブ/レシーブ別3本ずつ）
  def decided_at_distribution
    {
      all:     decided_at_group(@patterns),
      serve:   decided_at_group(@serve_patterns),
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
    { label:, score:, lost_score:, rate:, share: 0 }
  end

  def append_share(entries)
    total = entries.sum { |e| e[:score] }
    entries.map do |e|
      share = total.positive? ? (e[:score].to_f / total * 100).round : 0
      e.merge(share:)
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
      { label:, score: grp.count(&:won), lost_score: grp.count { |p| !p.won } }
    end
  end
end
```

**重要ポイント**:
- `origin` enum はプレフィックス `:origin` 付き（`origin_serve?` / `origin_receive?`）。
- `attack_style` enum もプレフィックス `:attack` 付き。`attack_style` の値はシンボルキーか文字列かを `attack_label` で吸収する。
- `receive_style` は integer（enum ではない）で `RECEIVE_STYLE_VALUES` で逆引き。
- `RECEIVE_STYLE_VALUES_USED` は `ServeReceivePattern::RECEIVE_STYLE_VALUES` を参照（定数はモデル側にある）。

### Step 2: showアクションに `analysis_type` 分岐を追加

**ファイル**: `app/controllers/match_infos_controller.rb`

```ruby
def show
  set_match_info_scores
  if @match_info.serve_receive?
    @srp_analysis = ServeReceiveAnalyzer.new(@match_info)
  else
    # 既存のAIアドバイス処理（変更なし）
    if @match_info.advice.present?
      @advice = @match_info.advice
    else
      advice = ChatgptService.get_advice(@match_info)
      @match_info.update_advice(advice)
      @advice = advice
    end
  end
end
```

`set_match_info_scores` は変更不要（`@match_info` と `@batting_scores` を取得）。

### Step 3: `_serve_receive_score_table.html.erb` partial 新規作成

**ファイル**: `app/views/match_infos/_serve_receive_score_table.html.erb`

`_batting_score_table.html.erb` のレスポンシブ2テーブル構造・プログレスバー・ランクバッジを流用しつつ、技術名表示を `label` 直挿しに変更する。

- `locals`: `data` (array), `theme` (:player or :opponent), `show_share` (boolean, default true)
- `data` の各要素: `{ label:, score:, lost_score:, rate:, share: }`
- 技術名セルは `<td><%= entry[:label] %></td>` に（`Score.human_enum_name` 呼び出し不要）
- プログレスバーの `bar_width` は `theme == :player ? entry[:rate] : (100 - entry[:rate])` で計算（`_batting_score_table` と同ロジック）
- `show_share` が false の場合、シェア列を非表示（決着タイミング分布テーブルで使用）

### Step 4: `_serve_receive_analysis.html.erb` partial 新規作成

**ファイル**: `app/views/match_infos/_serve_receive_analysis.html.erb`

```
locals: srp_analysis (ServeReceiveAnalyzer)
```

**セクション構成**:

```
[データなしの場合]
  「まだ得点データがありません」メッセージ

[データあり]
  h2: 「サーブ起点の分析」
    h3: 「サーブ長さ別得点率」
      render '_serve_receive_score_table', data: srp_analysis.serve_length_stats, theme: :player
    h3: 「サーブ→3球目 パターン別」
      render '_serve_receive_score_table', data: srp_analysis.serve_pattern_stats, theme: :player

  h2: 「レシーブ起点の分析」
    h3: 「レシーブ技術別得点率」
      render '_serve_receive_score_table', data: srp_analysis.receive_style_stats, theme: :player
    h3: 「レシーブ→4球目 パターン別」
      render '_serve_receive_score_table', data: srp_analysis.receive_pattern_stats, theme: :player

  h2: 「決着タイミング分布」
    (サーブ・レシーブ・全体 の3列を横並びカード or テーブルで表示)
    render '_serve_receive_score_table', data: dist[:serve], theme: :player, show_share: false
    render '_serve_receive_score_table', data: dist[:receive], theme: :player, show_share: false
    render '_serve_receive_score_table', data: dist[:all], theme: :player, show_share: false
```

各セクションは `data.empty?` の場合「データなし」メッセージを表示して skip。

### Step 5: `show.html.erb` に分岐を追加

**ファイル**: `app/views/match_infos/show.html.erb`

既存コードの先頭付近に分岐を追加:

```erb
<% if @match_info.serve_receive? %>
  <%= render 'match_infos/match_info_detail', match_info: @match_info %>
  <%= render 'match_infos/serve_receive_analysis', srp_analysis: @srp_analysis %>
<% else %>
  <%# 既存の表示（rallies/アドバイス/スコア推移）をそのまま %>
  ...
<% end %>
```

`_match_info_detail` はゲームスコア表示を含むため両方で流用できる。

### Step 6: テスト

**`spec/services/serve_receive_analyzer_spec.rb`** 新規作成:

```
- describe #serve_length_stats
  - ショートサーブで3得点2失点のデータ → rate: 60, label: "ショート"
  - データなし → 空配列
- describe #serve_pattern_stats
  - 同一組み合わせを複数件 → まとめて集計
  - label フォーマット確認（"ショート 下回転+順横回転 → フォアドライブ（対下）"）
- describe #receive_style_stats
  - receive_style あり → 正しくラベル表示
- describe #receive_pattern_stats
  - 組み合わせ別集計・ソート確認
- describe #decided_at_distribution
  - attack_ball / follow_ball / rally それぞれ集計
  - serve / receive 分離確認
- describe #empty?
  - patternがゼロのとき true
```

**`spec/requests/match_infos_spec.rb`** に追記:

```
- GET /match_infos/:id (serve_receive? な match_info)
  - 200を返すこと
  - @srp_analysis が ServeReceiveAnalyzer のインスタンスであること
  - AIアドバイス処理が呼ばれないこと
```

---

## 流用する既存実装

| 用途 | 流用元 |
|------|--------|
| サービスクラスの構造 | `app/services/rally_context_builder.rb` |
| テーブルのHTML構造・レスポンシブ・バー | `app/views/match_infos/_batting_score_table.html.erb` |
| 技術の和名取得 | `Score.human_enum_name(:batting_style, key)` |
| 試合情報ヘッダー表示 | `app/views/match_infos/_match_info_detail.html.erb` |
| I18n キー（serve_length / decided_at） | `config/locales/ja.yml`（Sprint 1で追加済み） |
| SERVE_SPIN_NAMES_JA / RECEIVE_STYLE_VALUES | `app/models/serve_receive_pattern.rb` |

---

## 新規作成ファイル

| ファイル | 用途 |
|---------|------|
| `app/services/serve_receive_analyzer.rb` | 5軸集計ロジック |
| `app/views/match_infos/_serve_receive_score_table.html.erb` | ラベル直挿しテーブル partial |
| `app/views/match_infos/_serve_receive_analysis.html.erb` | 分析ページ全体 partial |
| `spec/services/serve_receive_analyzer_spec.rb` | サービステスト |

## 変更ファイル

| ファイル | 変更内容 |
|---------|---------|
| `app/controllers/match_infos_controller.rb` | show アクションに `serve_receive?` 分岐を追加 |
| `app/views/match_infos/show.html.erb` | `serve_receive?` 分岐で新 partial をレンダー |

---

## 検証方法

1. `bundle exec rspec && bundle exec rubocop --parallel` が両方グリーン
2. `curl -s -o /dev/null -w "%{http_code}" http://localhost:3000` が 200
3. ブラウザ操作:
   - Sprint 2 で作成したサーブ・レシーブ分析の試合を `show` ページで開く
   - 5セクション（サーブ長さ別 / サーブパターン別 / レシーブ別 / レシーブパターン別 / 決着タイミング）が表示されること
   - 入力データが0件の試合では「データなし」メッセージが出ること
   - 既存の `technique` 分析の show ページが壊れていないこと（AIアドバイス・スコア推移が正常表示）
