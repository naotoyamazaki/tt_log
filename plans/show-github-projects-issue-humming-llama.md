# showページ技術別集計表の新仕様対応（2テーブル化）

## Context

試合データ入力がラリーベース入力（Rally モデル）に変更された。これに伴い Score テーブルの意味が変わった。

- **旧仕様**：`score` = 自分がその技術で得点、`lost_score` = 自分がその技術を使って失点
- **新仕様**（`aggregate_scores_from_rallies` 経由）：`score` = その技術ポイントを自分が取った回数、`lost_score` = 相手が取った回数

showページの「技術ごとの得点率ランキング」は旧仕様前提の単一テーブルのままであり、表の意味が実態と乖離している。改修により「自分の得点技術ランキング」と「相手の得点技術ランキング」の2テーブル構成に変え、新データでは実態に合った分析表示を実現する。旧データ（Rallyなし）との後方互換性も保つ。

---

## スプリント構成

| Sprint | 内容 |
|--------|------|
| Sprint 1 | ヘルパーに新集計メソッドを追加 + RSpecテスト作成 |
| Sprint 2 | ビューを2テーブル構成に改修（N+1対策含む） |

---

## Sprint 1：ヘルパー改修 + テスト

### 変更ファイル

`app/helpers/application_helper.rb`

### 追加メソッド

`private` より上に2メソッドを追加する。

```ruby
# 自分の得点技術ランキング（score 降順）
def player_scoring_techniques(batting_scores)
  aggregated = batting_scores.group_by(&:batting_style).map do |batting_style, scores|
    build_aggregated_score_data(batting_style, scores)
  end
  aggregated
    .reject { |e| e[:score].zero? && e[:lost_score].zero? }
    .sort_by { |e| [-e[:score], -e[:lost_score]] }
end

# 相手の得点技術ランキング（lost_score 降順）。opponent_rate キーを付与
def opponent_scoring_techniques(batting_scores)
  aggregated = batting_scores.group_by(&:batting_style).map do |batting_style, scores|
    data = build_aggregated_score_data(batting_style, scores)
    total = data[:score] + data[:lost_score]
    opponent_rate = total.positive? ? (data[:lost_score].to_f / total * 100).round : 0
    data.merge(opponent_rate: opponent_rate)
  end
  aggregated
    .reject { |e| e[:score].zero? && e[:lost_score].zero? }
    .sort_by { |e| [-e[:lost_score], -e[:score]] }
end
```

### 新規テストファイル

`spec/helpers/application_helper_spec.rb`（新規作成）

テスト観点：
- `player_scoring_techniques`：score 降順ソート、0/0 除外、`:rate` が自分得点率
- `opponent_scoring_techniques`：lost_score 降順ソート、0/0 除外、`:opponent_rate` が相手得点率

---

## Sprint 2：ビュー改修 + N+1対策

### 2-1. N+1対策（コントローラー）

`app/controllers/match_infos_controller.rb` の `set_match_info_scores` を変更：

```ruby
def set_match_info_scores
  @match_info = current_user.match_infos.includes(games: [:rallies, :scores]).find(params[:id])
  @batting_scores = @match_info.scores.where.not(batting_style: :receive)
end
```

既存の `set_match_info` と同じく、必ず `current_user.match_infos` 経由で取得して認可スコープを維持する。

### 2-2. 新パーシャル作成

`app/views/match_infos/_batting_score_table.html.erb`（新規作成）

ローカル変数：`data`（配列）、`rate_key`（`:rate` or `:opponent_rate`）、`rate_label`（表示文字列）

モバイル（`d-md-none`）とデスクトップ（`d-none d-md-table`）の2テーブルを含む共通パーシャル。

### 2-3. `_match_info_detail.html.erb` の改修

行47-94（`技術ごとの得点率ランキング` セクション）を2テーブル構成に置き換え。

新旧データ判定：`@match_info.games.any? { |g| g.rallies.any? }`

- **新データ**：`player_scoring_techniques` / `opponent_scoring_techniques` を使い2テーブル表示
- **旧データ**：既存の `calculate_batting_score_data` で単一テーブル表示（後方互換）

### 2-4. `_game_score_breakdown.html.erb` の改修

ゲームごとに `game.rallies.any?` で判定：
- **新データ**：自分の得点技術 + 相手の得点技術の2テーブル
- **旧データ**：既存の単一テーブル

`_batting_score_table` パーシャルを再利用することでモバイル/デスクトップの重複記述を排除。

N+1を避けるため、ビュー内では `game.scores.where.not(...)` のように関連ごとのSQLを発行しない。
`set_match_info_scores` で preload 済みの `game.scores` を使い、Ruby側で `receive` を除外する。

```ruby
game_scores = game.scores.reject { |score| score.batting_style == "receive" }
```

---

## 変更ファイル一覧

| ファイル | 種別 |
|---------|------|
| `app/helpers/application_helper.rb` | 変更 |
| `app/controllers/match_infos_controller.rb` | 変更 |
| `app/views/match_infos/_match_info_detail.html.erb` | 変更 |
| `app/views/match_infos/_game_score_breakdown.html.erb` | 変更 |
| `app/views/match_infos/_batting_score_table.html.erb` | 新規 |
| `spec/helpers/application_helper_spec.rb` | 新規 |

---

## 検証方法

1. `bundle exec rspec spec/helpers/application_helper_spec.rb` でヘルパーテストをパス
2. `bundle exec rspec` で全テストをパス
3. `bundle exec rubocop --parallel` でLintをパス
4. ブラウザでshowページを開き、新データ（Rally入力済みの試合）で2テーブルが表示されることを確認
5. 旧データ（直接Score入力の試合）で旧来の単一テーブルが崩れていないことを確認
