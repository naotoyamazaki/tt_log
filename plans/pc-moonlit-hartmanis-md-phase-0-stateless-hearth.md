# ③ Phase 0: データ集計基盤＋成長ダッシュボード 実装プラン

## Context（なぜこの実装をするのか）

`pc-moonlit-hartmanis.md` ロードマップの③にあたる作業。T.T.LOG は現在「1試合を深く分析する」機能は完成度が高い一方、複数試合をまたいだ成長分析が存在しない。今後「積み上げ型SaaS」として月額課金（Phase 3）へ進化させる方針の第一歩として、まず**既存データだけで作れて初日から価値が出る、低リスクな集計基盤**を用意し、「積み上げ分析はユーザーに刺さるか」を最安コストで検証する。

最初のスコープは「フォアドライブ（対上回転）の得点率推移を月別表示」という最小単位に絞り、集計・表示の型を確立してから他の技術・週別表示へ広げる。将来 Phase 3 で「無料会員は直近◯試合のみ閲覧可」のような制限を導入する想定があるため、集計ロジックは対象試合範囲を外部から絞り込める設計にしておく。

## 全体方針

- 新規サービスクラス `app/services/growth_dashboard_aggregator.rb` を作成し、`RallyContextBuilder`（`app/services/rally_context_builder.rb`）と同じ「対象データを受け取り、集計結果のPORO/配列を返す」パターンを踏襲する。モデルには集計ロジックを持たせない（複数試合横断・時系列group化・範囲絞り込みという複数の関心事を持たせるとモデルが肥大化するため）。
- 集計はRubyレベルの `group_by`（`beginning_of_month` 丸め）で行う。初期フェーズはユーザーあたりの試合数が少なくパフォーマンス上の懸念が薄いため、PostgreSQL依存の `date_trunc` などは使わない。既存の `ApplicationHelper#build_aggregated_score_data`（`app/helpers/application_helper.rb`）と同じ「score/(score+lost_score)*100を四捨五入、0除算は0扱い」というレート計算ロジックを、サービス内に軽量なメソッドとして持たせる（ヘルパーをサービスから呼ぶ結合は避ける）。
- **フリーミアム制限を見据えた設計**: `GrowthDashboardAggregator` はコンストラクタで `match_infos`（既にfilter済みのActiveRecordリレーション）を受け取る。将来 Phase 3 で「直近N試合のみ」等の絞り込みを追加する際は、呼び出し側（コントローラー）で `match_infos` を絞ってから注入するだけで済み、サービス内部の変更は不要にする。

## データ集計仕様（Sprint 1確定事項）

- 対象技術: **`fore_drive_vs_topspin`（対上回転フォアドライブ）のみ**を対象にする。対下回転は将来スプリントで技術選択UIを追加した際に選べるようにする（Sprint 2）。
- 集計単位: 月別（`match_info.match_date` を `beginning_of_month` に丸める）。
- データがない月は**グラフ上から省く**（0%で埋めない）。折れ線が飛び飛びになる方が「試合をしていない月」という実態に即しており誤解を招かない。
- 試合数が0件のユーザーには空状態のビューを表示する。

## `GrowthDashboardAggregator` 設計

```ruby
class GrowthDashboardAggregator
  def initialize(match_infos:, batting_style:, period: :month)
    ...
  end

  # => [{ period_label: "2026-08", rate: 62, score: 10, lost_score: 6, match_count: 3 }, ...]
  def monthly_rate_series
    ...
  end
end
```

- `match_infos`: コントローラーが `current_user.match_infos` を渡す（`includes(:scores)` でN+1回避）。
- `batting_style`: Sprint 1では `fore_drive_vs_topspin` 固定で呼び出すが、任意のキーを受け付けられる設計にしておく（Sprint 2でセレクトボックスからの値をそのまま渡せるように）。
- `period`: Sprint 1では `:month` のみ実装。`:week`（`beginning_of_week` 丸め）はSprint 3で拡張。
- 戻り値はコントローラー側で `labels: [...]`, `data: [...]` にそのまま変換できる配列構造にする。

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
- ナビゲーション: `app/views/shared/_header.html.erb` の「試合分析」ドロップダウン内に「成長ダッシュボード」リンクを追加（デスクトップ版・モバイル版 `d-lg-none` の両方、既存の「サーブ・レシーブ分析を開始」リンクと同じ追加パターン）。

## テスト方針

- `spec/services/growth_dashboard_aggregator_spec.rb`: 複数月にまたがるMatchInfo/Score fixtureで月別集計・0除算・データなし月のスキップを検証。
- `spec/requests/growth_dashboards_spec.rb`: 未ログイン時のリダイレクト、正常系でグラフ用データがviewに渡ることを検証。

## スプリント分割

Phase 0は複数スプリントに分割し、CLAUDE.mdのルール通りスプリントごとにブランチ・PRを作成、次スプリントに進む前に必ずPRマージを完了させる。

### Sprint 1 — フォアドライブ得点率・月別推移の最小実装（MVP）
- ブランチ: `feature/sprint-1-growth-dashboard`
- スコープ: `GrowthDashboardAggregator`（`fore_drive_vs_topspin` 固定、`:month` のみ）／ `growth_dashboards#index` ルーティング・コントローラー・ビュー（技術選択UIなし）／ Chart.js importmap導入＋`growth_chart_controller.js`／ヘッダーへのナビリンク追加／サービス層＋リクエストスペック
- 完了条件: ログイン後 `/growth_dashboards` にアクセスすると、フォアドライブ（対上回転）の得点率が月別折れ線グラフで表示される。試合データが0件なら空状態メッセージが出る。`bundle exec rspec && bundle exec rubocop --parallel` が緑。

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
3. ブラウザ操作: ログイン → ヘッダーの「成長ダッシュボード」リンクから遷移 → 複数月にまたがる試合データを持つユーザーでフォアドライブの得点率推移グラフが正しく表示されることを確認。試合データがないユーザーでは空状態メッセージが表示されることを確認。

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
