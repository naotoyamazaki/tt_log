# ③ Phase 0: データ集計基盤＋成長ダッシュボード 実装プラン

## Context（なぜこの実装をするのか）

`pc-moonlit-hartmanis.md` ロードマップの③にあたる作業。T.T.LOG は現在「1試合を深く分析する」機能は完成度が高い一方、複数試合をまたいだ成長分析が存在しない。今後「積み上げ型SaaS」として月額課金（Phase 3）へ進化させる方針の第一歩として、まず**既存データだけで作れて初日から価値が出る、低リスクな集計基盤**を用意し、「積み上げ分析はユーザーに刺さるか」を最安コストで検証する。

最初のスコープは「フォアドライブ（対上回転）の得点率推移を月別表示」という最小単位に絞り、集計・表示の型を確立してから他の技術・週別表示へ広げる。将来 Phase 3 で「無料会員は直近◯試合のみ閲覧可」のような制限を導入する想定があるため、集計ロジックは対象試合範囲を外部から絞り込める設計にしておく。

## 【重要】Sprint 1実装後に発覚した設計上の問題と対応方針

Sprint 1をevaluator合格まで実装した後、ユーザーの手動確認で「得点率が常に100%近くになる」致命的な問題が発覚した。

**原因**: `Score`の`score`/`lost_score`は「1ポイントを決定づけた技術」を勝敗で振り分けているだけ（`app/javascript/controllers/rally_input_controller.js`の`selectWinner`→`selectStyle`で、ラリーごとに「勝者」と「技術」を1つだけ記録する仕様）。自分がフォアドライブを打って決まったときだけ`score`に加算され、自分がフォアドライブを打ってミスした場合は「フォアドライブの失点」として記録されず、別の技術（ネットorエッジ等）や相手の得点技術として記録される。相手が全く同じ技術名で自分から得点する場面は稀なので`lost_score`がほぼ0になり、`score/(score+lost_score)`という計算式では常に100%近くになってしまう。

**結論**: これは成長ダッシュボードの集計ロジックの不具合ではなく、**そもそも既存のラリー記録の仕様上、技術ごとの「成功率」を測れるデータが存在しない**という構造的な制約。「自分がその技術を使った際の成功率」を正しく出すには入力側（ラリー記録の仕様）の再設計が必要で、これは技術別得点率表示・AIアドバイス生成・`RallyContextBuilder`など既存の主要機能全体が依存する中核データに手を入れる大改修になるため、Phase 0のスコープを大きく超える。そのため今回は着手しない（別途独立した企画として将来検討する）。

**Sprint 1の対応**: 指標を「得点率（成功率）」から**「得点内訳における使用率（シェア）」**に変更する。既存の`ApplicationHelper#player_scoring_techniques`と同じ考え方で、「その月に自分が取った全得点（`receive`を除く）のうち、対象技術が占める割合」を月別に出す。得点数（絶対数）ではなく使用率（シェア、%）を採用する理由は、得点数は試合数の多寡に左右されるノイズの多い指標であり、月別の推移で「上達したか」ではなく「その月に多く試合をしたか」を測ってしまうため。使用率は試合数の多寡に対して相対的に頑健で、「得意技として頼っている度合いの推移」を見るのに適している。この指標は「成功率」ではなく「使用の偏り」を示すものである点を、UI上のラベルでも明確にする（「得点率」ではなく「得点内訳での使用率」等の表記に修正）。

## 全体方針

- 新規サービスクラス `app/services/growth_dashboard_aggregator.rb` を作成し、`RallyContextBuilder`（`app/services/rally_context_builder.rb`）と同じ「対象データを受け取り、集計結果のPORO/配列を返す」パターンを踏襲する。モデルには集計ロジックを持たせない（複数試合横断・時系列group化・範囲絞り込みという複数の関心事を持たせるとモデルが肥大化するため）。
- 集計はRubyレベルの `group_by`（`beginning_of_month` 丸め）で行う。初期フェーズはユーザーあたりの試合数が少なくパフォーマンス上の懸念が薄いため、PostgreSQL依存の `date_trunc` などは使わない。既存の `ApplicationHelper#build_aggregated_score_data`（`app/helpers/application_helper.rb`）と同じ「score/(score+lost_score)*100を四捨五入、0除算は0扱い」というレート計算ロジックを、サービス内に軽量なメソッドとして持たせる（ヘルパーをサービスから呼ぶ結合は避ける）。
- **フリーミアム制限を見据えた設計**: `GrowthDashboardAggregator` はコンストラクタで `match_infos`（既にfilter済みのActiveRecordリレーション）を受け取る。将来 Phase 3 で「直近N試合のみ」等の絞り込みを追加する際は、呼び出し側（コントローラー）で `match_infos` を絞ってから注入するだけで済み、サービス内部の変更は不要にする。

## データ集計仕様（Sprint 1確定事項・修正版）

- 対象技術: **`fore_drive_vs_topspin`（対上回転フォアドライブ）のみ**を対象にする。対下回転は将来スプリントで技術選択UIを追加した際に選べるようにする（Sprint 2）。
- 集計単位: 月別（`match_info.match_date` を `beginning_of_month` に丸める）。
- **指標: 使用率（シェア）**。当月の対象ユーザーの全得点（`receive`を除く全`batting_style`の`score`合計）に対して、対象技術の`score`が占める割合(%)。`lost_score`は使わない。
- データがない月（その月の全得点合計が0）は**グラフ上から省く**（0%で埋めない）。折れ線が飛び飛びになる方が「試合をしていない月」という実態に即しており誤解を招かない。
- 試合数が0件のユーザーには空状態のビューを表示する。

## `GrowthDashboardAggregator` 設計（修正版）

```ruby
class GrowthDashboardAggregator
  def initialize(match_infos:, batting_style:, period: :month)
    ...
  end

  # => [{ period_label: "2026-08", share: 62, score: 10, total_score: 16, match_count: 3 }, ...]
  def monthly_usage_share_series
    ...
  end
end
```

- `match_infos`: コントローラーが `current_user.match_infos` を渡す（`includes(:scores)` でN+1回避）。
- `batting_style`: Sprint 1では `fore_drive_vs_topspin` 固定で呼び出すが、任意のキーを受け付けられる設計にしておく（Sprint 2でセレクトボックスからの値をそのまま渡せるように）。
- `period`: Sprint 1では `:month` のみ実装。`:week`（`beginning_of_week` 丸め）はSprint 3で拡張。
- 集計ロジック: 期間内の`match_info.scores`から`receive`を除外した全レコードの`score`合計を`total_score`とし、対象`batting_style`の`score`合計を`target_score`として`share = target_score / total_score * 100`（四捨五入、`total_score`が0なら期間自体を結果から除外）。
- 戻り値はコントローラー側で `labels: [...]`, `data: [...]` にそのまま変換できる配列構造にする。
- メソッド名は`monthly_rate_series`から`monthly_usage_share_series`に変更し、戻り値のキーも`rate`/`lost_score`から`share`/`total_score`に変更する（呼び出し元コントローラー・ビュー・JS・specすべて追随）。

## グラフ描画（Chart.js）

- グラフ描画ライブラリは未導入のため新規追加する。`config/importmap.rb` に既存の `@popperjs/core` / `bootstrap` と同じCDN pin方式で追加:
  ```ruby
  pin "chart.js", to: "https://ga.jspm.io/npm:chart.js@4.x.x/auto/auto.js"
  ```
- 新規Stimulusコントローラー `app/javascript/controllers/growth_chart_controller.js` を追加。`rally_input_controller.js`（`app/javascript/controllers/rally_input_controller.js`）のJSON受け渡しパターンを踏襲し、ビュー側で集計データをJSONとしてStimulus valueに埋め込み、`connect()` で `JSON.parse` → `new Chart(canvas, {...})`。
- Turbo Drive遷移時の多重描画・メモリリークを防ぐため `disconnect()` でChartインスタンスを破棄する。

## ルーティング・コントローラー・ビュー

- ルーティング: `config/routes.rb` に `resources :growth_dashboards, only: [:index]` を追加。
- コントローラー: `app/controllers/growth_dashboards_controller.rb` 新規作成。
  - `before_action :require_login`（`match_infos_controller.rb` と同じ既存パターンを踏襲）。
  - `index` アクション: `fore_drive_vs_topspin` 固定で `GrowthDashboardAggregator` を呼び出し、`@series` をビューへ渡す。
- ビュー: `app/views/growth_dashboards/index.html.erb` 新規作成。
  - `<canvas>` + Stimulusコントローラーのdata属性でグラフ描画。
  - `app/assets/stylesheets/match_infos.scss` の `.card` / `.section-card` パターンを踏襲したカードUIで囲み、既存デザイン（`--tt-primary` 緑基調のライトテーマ）と一貫させる。
  - 試合データが0件の場合の空状態メッセージを表示。
  - 見出し・軸ラベルは「得点率」ではなく**「得点内訳における使用率」**等、成功率ではなくシェアであることが伝わる表記にする（「得点率」という言葉は使わない）。
- ナビゲーション: `app/views/shared/_header.html.erb` の「試合分析」ドロップダウン内に「成長ダッシュボード」リンクを追加（デスクトップ版・モバイル版 `d-lg-none` の両方、既存の「サーブ・レシーブ分析を開始」リンクと同じ追加パターン）。

## テスト方針

- `spec/services/growth_dashboard_aggregator_spec.rb`: 複数月にまたがるMatchInfo/Score fixtureで月別使用率(share)集計・`receive`除外・0除算・データなし月（合計0）のスキップを検証。**対象技術で相手が得点した`lost_score`が多くても、使用率（自分の得点内訳シェア）には影響しないことも検証**（旧「得点率」定義との違いを明示するケース）。
- `spec/requests/growth_dashboards_spec.rb`: 未ログイン時のリダイレクト、正常系でグラフ用データがviewに渡ることを検証。

## スプリント分割

Phase 0は複数スプリントに分割し、CLAUDE.mdのルール通りスプリントごとにブランチ・PRを作成、次スプリントに進む前に必ずPRマージを完了させる。

### Sprint 1 — フォアドライブ使用率・月別推移の最小実装（MVP）
- ブランチ: `feature/sprint-1-growth-dashboard`（実装済み・修正対応中。まだPR/マージ前）
- スコープ: `GrowthDashboardAggregator`（`fore_drive_vs_topspin` 固定、`:month` のみ、**指標は使用率(share)**）／ `growth_dashboards#index` ルーティング・コントローラー・ビュー（技術選択UIなし）／ Chart.js importmap導入＋`growth_chart_controller.js`／ヘッダーへのナビリンク追加／サービス層＋リクエストスペック
- 完了条件: ログイン後 `/growth_dashboards` にアクセスすると、フォアドライブ（対上回転）の**得点内訳における使用率**が月別折れ線グラフで表示される。試合データが0件なら空状態メッセージが出る。`bundle exec rspec && bundle exec rubocop --parallel` が緑。
- **修正履歴**: 初回実装は「得点率（成功率）」を指標としていたが、`Score`データの記録仕様上、常に100%近くになる致命的な問題が判明。指標を「使用率（シェア）」に変更する修正を同ブランチに追加コミットする。

### Sprint 2 — 技術選択機能の追加
- ブランチ: `feature/sprint-2-growth-dashboard`
- スコープ: `Score.allowed_batting_styles` を使った技術選択セレクトボックスを追加し `params[:batting_style]` で切り替え可能にする／不正な値へのフォールバック処理
- 完了条件: セレクトボックスで技術を切り替えるとグラフが再描画される（GETリクエストでの再レンダリングで可）。テスト・Lint緑。

### Sprint 3 — 週別表示への対応
- ブランチ: `feature/sprint-3-growth-dashboard`
- スコープ: `GrowthDashboardAggregator` に `period: :week` を追加／月別・週別の切り替えUI
- 完了条件: 週別・月別を切り替えて表示できる。テスト・Lint緑。

### Sprint 4（任意・優先度低）— 技術別ランキング表示の追加
- ブランチ: `feature/sprint-4-growth-dashboard`
- スコープ: ダッシュボード上に技術別得点率ランキングカードを追加（`_batting_score_table.html.erb` や `player_scoring_techniques` ヘルパーの複数試合横断向け拡張）
- 完了条件: ダッシュボードにランキングテーブルが表示される。テスト・Lint緑。

## 検証方法（end-to-end）

1. `bundle exec rspec && bundle exec rubocop --parallel` が両方パス
2. `curl -s -o /dev/null -w "%{http_code}" http://localhost:3000` が 200
3. ブラウザ操作: ログイン → ヘッダーの「成長ダッシュボード」リンクから遷移 → 複数月にまたがる試合データを持つユーザーでフォアドライブの**使用率**推移グラフが正しく表示されることを確認（相手がフォアドライブで得点した`lost_score`を多く含むデータでも、使用率の値が不当に低くならない＝100%固定バグが再発していないことを確認）。試合データがないユーザーでは空状態メッセージが表示されることを確認。

## Critical Files

- `app/models/match_info.rb` / `app/models/score.rb` — 集計対象のデータ構造
- `app/helpers/application_helper.rb` — 参考にするレート計算ロジック（`build_aggregated_score_data`）
- `app/services/rally_context_builder.rb` — 踏襲するサービス層パターン
- `config/routes.rb` / `config/importmap.rb`
- `app/javascript/controllers/rally_input_controller.js` — 踏襲するJSON受け渡しパターン
- `app/views/shared/_header.html.erb` — ナビリンク追加箇所

## 次回セッション開始時のアクション

1. このファイルを読み直し、Sprint 1のブランチ（`feature/sprint-1-growth-dashboard`）を切って着手
2. Sprint 1完了後、RSpec/RuboCop確認 → PR作成（ユーザー指示があれば）→ マージ完了後にSprint 2へ
