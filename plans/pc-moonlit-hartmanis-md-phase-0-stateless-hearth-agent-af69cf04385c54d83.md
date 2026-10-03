# Phase 0: データ集計基盤＋成長ダッシュボード 実装プラン

## 1. 全体方針

- **新規サービスクラスを `app/services/` に作る**。`RallyContextBuilder` / `ServeReceiveAnalyzer` と同じ「対象データ（match_infos/scores）を受け取り、集計結果のPlain Old Rubyデータを返す」パターンを踏襲する。
  - モデルにscopeを生やすだけでは「複数試合を横断し、時系列でgroup化し、範囲を絞る」という複数の関心事を持つロジックを持たせづらい。将来Phase3で「直近N試合のみ」「premiumは全期間」といった条件分岐が増える見込みがあるため、独立したサービスクラスに寄せておく方が責務が明確でテストしやすい。
  - モデル側には最小限、`MatchInfo` に `scope :for_user(user)` 程度の薄いscopeのみ置き、集計ロジック自体はモデルに持たせない。
- **サービス名**: `GrowthDashboardAggregator`（`app/services/growth_dashboard_aggregator.rb`）
  - 責務: 「あるuserの、ある技術(batting_style)について、月別（将来は週別も）の得点率推移データを返す」
  - 対象範囲を絞れるように、コンストラクタ引数として `match_infos` のリレーション（既にfilter済みのものを注入できる）を受け取る設計にし、"直近N件"のようなフィルタはサービスの外（呼び出し側 or 将来のPolicyオブジェクト）で組み立てて渡す形にする。これによりPhase3で `FreemiumPolicy` 的なものを追加する際、`GrowthDashboardAggregator.new(match_infos: policy.visible_match_infos(user))` のように差し込むだけで済み、集計ロジック自体に課金分岐を持ち込まずに済む。

## 2. 集計クエリ設計

- **Rubyレベル集計を採用**（DBの `date_trunc` 等PostgreSQL依存構文は使わない）。
  - 理由: 現状ユーザーあたりの試合数は少なく（初期フェーズ）、パフォーマンス上の懸念が薄い。`group("date_trunc('month', match_date)")` のようなDB依存SQLは可読性・テスト容易性を下げ、SQLiteでのテスト実行（もし使っていれば）や将来のDB移行にも足かせになる。
  - 具体的には:
    1. `match_infos = MatchInfo.where(user: user).includes(:scores)` などで対象試合を取得（N+1回避のため `includes` または `joins(:scores).select(...)` で必要列のみ取得することを検討）。
    2. 各 `match_info` から `scores.select { |s| s.batting_style == target_style }` を集め、`match_info.match_date` を `beginning_of_month` に丸めたキーで `group_by` する。
    3. 月ごとに `build_aggregated_score_data` 相当のロジック（sum score / sum lost_score → rate）を適用し、`{ period: "2026-08", rate: 62, score: 10, lost_score: 6, match_count: 3 }` のような配列を月の昇順で返す。
  - `ApplicationHelper#build_aggregated_score_data` は「Scoreの配列を渡せば動く」設計なので、月ごとのScore配列に対してそのまま再利用できる（ヘルパーをサービスからincludeするか、同等のロジックをサービス内に複製せず、`ApplicationHelper` をextendして呼ぶ、または計算ロジックを小さなモジュールに切り出して両者から呼ぶ形にする）。今回は既存ヘルパーとの結合を避け、サービス内に軽量な集計メソッドを持たせる方針（ヘルパーをサービスから呼ぶのはRailsの層設計として不自然なため）。
  - パフォーマンスが問題になった場合の拡張余地として、将来的に `Score.joins(:match_info).where(match_info: { user: user }, batting_style: style).group("date_trunc('month', match_infos.match_date)").sum(:score)` のようなDB集計に差し替えられるよう、サービスの公開インターフェース（引数・戻り値の形）はRuby実装/SQL実装のどちらでも変わらない形にしておく。

## 3. `GrowthDashboardAggregator` の設計案

```
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

- `match_infos`: 呼び出し側（コントローラー）が `current_user.match_infos` を渡す。将来のフリーミアム制限は呼び出し側で `current_user.match_infos.order(match_date: :desc).limit(N)` のように絞り込んでから注入すればよく、サービス内部を変更しなくて良い。
- `batting_style`: 単一の技術キー（シンボル/文字列）。Phase 0では `fore_drive_vs_topspin` と `fore_drive_vs_backspin` をまとめて「フォアドライブ」として合算するか、まずは片方（`fore_drive_vs_topspin`）のみを対象にするかは要検討事項として明記（後述のSprint 1のスコープで確定）。
- `period`: `:month` のみSprint 1では対応。`:week` はSprint 3で拡張（`beginning_of_week` に丸めるだけで済む設計にしておく）。
- 戻り値は「Chart.jsにそのまま渡せる形」を強く意識し、コントローラー側で `labels: [...]、data: [...]` に変換しやすい構造にする。

### バリデーション/エッジケース
- 対象期間にデータがない月はスキップする（穴埋めするかは要検討。Sprint 1では「データがある月のみ表示」を採用し、UI側で「データが少ない」旨の注記を出す程度に留める）。
- 試合数が0件のユーザーには空状態のビューを出す。

## 4. グラフ描画方式（Chart.js）

- `config/importmap.rb` に以下を追加:
  ```
  pin "chart.js", to: "https://ga.jspm.io/npm:chart.js@4.x.x/auto/auto.js"
  ```
  （`chart.js/auto` を使うと個別コンポーネント登録が不要になり導入コストが低い。既存の `@popperjs/core` / `bootstrap` と同じCDN pin方式）
- 新規Stimulusコントローラー `app/javascript/controllers/growth_chart_controller.js` を追加。
  - `rally_input_controller.js` のJSON受け渡しパターンを踏襲: ビュー側で集計データをJSONとして `data-growth-chart-series-value` のようなStimulus valueに埋め込み、`connect()` 内で `JSON.parse` → Chart.jsの `new Chart(canvasElement, {...})` を呼ぶ。
  - `static values = { series: String, labels: String }` のように、ラベル配列と数値配列を分けて渡すか、`{ labels: [...], data: [...] }` を1つのJSONとして渡すかは実装時に決める（後者の方がシンプル）。
  - `disconnect()` でChartインスタンスを破棄し、Turbo Drive遷移時のメモリリーク/多重描画を防ぐ（Turboを使っている既存アプリのため必須の配慮）。

## 5. ルーティング・コントローラー・ビュー構成案

- ルーティング（`config/routes.rb`）:
  ```
  resources :growth_dashboards, only: [:index]
  ```
  または単一機能なので `get 'growth_dashboard', to: 'growth_dashboards#index'` でも良い。将来技術ごとにURLを分けたくなる可能性を考え、`resources :growth_dashboards, only: [:index]` としクエリパラメータ（`?batting_style=fore_drive_vs_topspin&period=month`）で条件を渡す設計を推奨。
- コントローラー: `app/controllers/growth_dashboards_controller.rb`
  - `before_action :require_login`（既存のSorcery認証パターンに合わせる。`application_controller.rb` の既存フィルタ名を確認して合わせること）
  - `index` アクション:
    ```
    def index
      @batting_style = params[:batting_style].presence || "fore_drive_vs_topspin"
      match_infos = current_user.match_infos
      @series = GrowthDashboardAggregator.new(match_infos: match_infos, batting_style: @batting_style).monthly_rate_series
    end
    ```
- ビュー: `app/views/growth_dashboards/index.html.erb`
  - 技術選択のセレクトボックス（Sprint 1ではフォアドライブ固定でもよいが、UIの拡張性を見せるため`select`はSprint 2で追加でも可）
  - グラフ描画用の `<canvas>` + Stimulusコントローラーをdata属性で紐付け
  - 既存の `match_infos.scss` の `.card` / `.section-card` パターンを踏襲したカードUIでグラフを囲む
  - 技術別ランキングの表示が欲しければ `_batting_score_table.html.erb` を流用可能（今回のPhase 0コアスコープではないため、Sprint 2以降の任意拡張とする）
- ナビゲーション: `app/views/shared/_header.html.erb` の「試合分析」ドロップダウン内（デスクトップ版 `d-none d-lg-block` とモバイル版 `d-lg-none` の両方）に「成長ダッシュボード」リンクを追加。

## 6. テスト方針

- `spec/services/growth_dashboard_aggregator_spec.rb`: 複数月にまたがるMatchInfo/Score fixtureを作り、月別集計・0除算・データなし月のスキップを検証（`rally_context_builder_spec.rb` のテストスタイルを踏襲）。
- `spec/requests/growth_dashboards_spec.rb`: ログイン必須であること、正常系でグラフ用データがviewに渡ること。
- 既存の `bundle exec rspec && bundle exec rubocop --parallel` がSprintごとに緑であることを完了条件にする。

## 7. フリーミアム制限（Phase 3）を見据えた設計配慮

- `GrowthDashboardAggregator` は `match_infos` を外部から注入する設計にしているため、Phase 3で「無料会員は直近5試合まで」等の制限を追加する際は、コントローラー層（または将来追加する `MatchInfoVisibilityPolicy` 的なクラス）で `match_infos` を絞り込んでから渡すだけで対応でき、集計ロジック自体の変更が不要。
- 今回のPhase 0では課金関連のコード（`current_user.premium?` 等の分岐）は一切書かない。あくまで「後から絞り込みを差し込みやすい引数設計」にとどめる。

## 8. スプリント分割案

### Sprint 1: フォアドライブ得点率・月別推移の最小実装（MVP）
- スコープ:
  - `GrowthDashboardAggregator`（`fore_drive_vs_topspin` 固定、`:month` のみ）
  - `growth_dashboards#index` ルーティング・コントローラー・ビュー（技術選択UIなし、固定表示）
  - Chart.js importmap導入 + `growth_chart_controller.js`
  - ヘッダーへのナビゲーションリンク追加
  - サービス層のRSpec + リクエストスペック
- 完了条件: ログイン後 `/growth_dashboards` にアクセスすると、フォアドライブの得点率が月別折れ線グラフで表示される。データが1件もない場合は空状態メッセージが出る。`bundle exec rspec && bundle exec rubocop --parallel` が緑。

### Sprint 2: 技術選択機能の追加（他の技術への一般化）
- スコープ:
  - `Score.allowed_batting_styles` を使った技術選択セレクトボックスをビューに追加し、`params[:batting_style]` で切り替え可能にする
  - `GrowthDashboardAggregator` が任意のbatting_styleを受け取れることを確認するテスト強化（Sprint 1で既に対応していれば設計変更は最小限）
  - 不正なbatting_style値のガード（存在しないキーが渡された場合のフォールバック処理）
- 完了条件: セレクトボックスで技術を切り替えるとグラフが再描画される（Turbo対応、ページ再読み込みでよい。フォームsubmitで`GET`リクエスト→再レンダリングのシンプルな実装で十分）。テスト・Lint緑。

### Sprint 3: 週別表示への対応
- スコープ:
  - `GrowthDashboardAggregator` に `period: :week` を追加（`beginning_of_week` 丸め）
  - ビューに月別/週別の切り替えUI（ラジオボタン等）を追加
- 完了条件: 週別・月別を切り替えて表示できる。テスト・Lint緑。

### Sprint 4（任意・優先度低）: 技術別ランキング表示の追加
- スコープ:
  - ダッシュボード上に「直近の技術別得点率ランキング」カードを追加（既存の `_batting_score_table.html.erb` や `player_scoring_techniques` ヘルパーを複数試合横断用に拡張、または新規メソッドとして流用）
- 完了条件: ダッシュボードにランキングテーブルが表示される。テスト・Lint緑。

各スプリントは個別ブランチ（例: `feature/growth-dashboard-sprint-1`）を切り、CLAUDE.mdのルールに従いPRマージ後に次スプリントへ進む。

## 9. 未確定事項（実装前に要確認・要判断）

- 「フォアドライブ」は `fore_drive_vs_topspin` と `fore_drive_vs_backspin` を合算するか、片方のみを対象にするか（要件文言は「フォアドライブの得点率推移」と技術を単数に丸めているため、Sprint 1着手前に確認推奨）。
- データが存在しない月を「グラフ上で欠落させる」か「0%として表示する」かのUX判断。
- `application_controller.rb` の認証フィルタ名（`require_login` 等）を実装時に確認し正確に合わせる。

## Critical Files for Implementation
- /Users/matsudairakenta/tt_log/app/models/match_info.rb
- /Users/matsudairakenta/tt_log/app/models/score.rb
- /Users/matsudairakenta/tt_log/app/helpers/application_helper.rb
- /Users/matsudairakenta/tt_log/app/services/rally_context_builder.rb
- /Users/matsudairakenta/tt_log/config/routes.rb
- /Users/matsudairakenta/tt_log/config/importmap.rb
- /Users/matsudairakenta/tt_log/app/javascript/controllers/rally_input_controller.js
- /Users/matsudairakenta/tt_log/app/views/shared/_header.html.erb
