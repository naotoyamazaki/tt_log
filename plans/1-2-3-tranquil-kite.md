# 成長ダッシュボード修正スプリント（3件）

## Context（なぜこの実装をするのか）

Phase 0で実装済みの成長ダッシュボード機能（`GrowthDashboardAggregator` / `GrowthDashboardsController` / `app/views/growth_dashboards/index.html.erb`）について、外部AIエージェント（Codex）からの指摘をユーザーがレビューし、以下3点が妥当と判断された：

1. **バグ**: 中断した下書き試合（`draft: true`）の部分的なスコアが集計に混入している
2. **用語**: 「使用率」という表記が「どのくらい使ったか」という誤解を招きやすく、実態（自分の得点のうち対象技術が占める割合）に即した「得点構成比」へ変更する
3. **UX**: グラフだけでは期間ごとの集計試合数・得点数などのサンプルサイズが見えず、小サンプルの急激な変動を過大評価しやすい。期間別の明細テーブルを追加して透明性を上げる

（Codexの提案のうち「総得点0の期間を非表示にする」は`build_period_entry`が`return nil if total_score.zero?`で既に対応済みのため対象外。「構成比上昇＝上達と断定する文言の修正」は明示的な断定文言が見当たらず優先度低のため今回のスコープ外）

ユーザー承認済みの進め方：
- **3つの独立したスプリント（ブランチ・PR）に分ける**（CLAUDE.mdの「スプリントごとにブランチ・PRを作成し、まとめてPRにしない」ルールに従う。優先度順: バグ修正→用語変更→テーブル追加）
- 用語変更はダッシュボード本体だけでなく、**LP（`top.html.erb`）とヘッダーのNEWバッジ説明文（`_header.html.erb`）も合わせて「得点構成比」に揃える**（表記の不一致を残さない）

---

## Sprint 1: draft試合の除外（バグ修正）

**ブランチ**: `fix/growth-dashboard-exclude-draft-matches`

### 問題の実体
`app/controllers/match_infos_controller.rb` の `persist_and_finalize_game`（200-209行）は、ゲーム終了ごとに`scores`を永続化しつつ`@match_info.update!(draft: true, ...)`で下書き状態を維持する。試合を最後まで完了せず中断すると、`draft: true`のまま一部ゲームの得点が永続化された`MatchInfo`が残る。

`app/controllers/growth_dashboards_controller.rb:9` の `current_user.match_infos.includes(:scores)` にはdraftフィルタが無いため、この中断試合の得点が成長ダッシュボードの集計に混入する。

### 変更内容
1. **`app/models/match_info.rb`**
   - `scope :completed, -> { where(draft: false) }` を追加（`enum :analysis_type`の直後、`validates`の前）
   - 集計目的の意図を表現するためscope化する（controllerで直接`where(draft: false)`も可能だが、「完了試合だけを対象にする」という意図を名前で明示する）
2. **`app/controllers/growth_dashboards_controller.rb`**
   - `current_user.match_infos.includes(:scores)` → `current_user.match_infos.completed.includes(:scores)`

### テスト
- `spec/requests/growth_dashboards_spec.rb` に新規コンテキスト「下書き（draft: true）の試合がある場合」を追加
  - draft試合に対象技術のスコアを持たせ、完了試合と同月のケース・draft試合単独のケース両方を確認
  - draft試合単独なら集計対象がなく空状態メッセージが表示されること、完了試合と混在する場合はdraft分の得点が`total_score`等に加算されず期待値と一致することを検証
- `spec/services/growth_dashboard_aggregator_spec.rb` は変更不要（Aggregatorはdraftの概念を知らず、呼び出し側でフィルタ済みの`match_infos`を受け取る設計のため。フィルタ責務はController/Modelのscope側に置く）

### 検証
- `bundle exec rspec && bundle exec rubocop --parallel`
- ブラウザ確認: 試合を中断（下書き保存）した状態を1件作り、成長ダッシュボードの集計に反映されないことを目視確認

---

## Sprint 2: 「使用率」→「得点構成比」への用語変更

**ブランチ**: `fix/growth-dashboard-terminology-share-to-composition`

### スコープ判断
- `app/views/match_infos/_batting_score_table.html.erb`（試合詳細ページ、単一試合内の技術別得点テーブル）は**別機能のため対象外**
- 成長ダッシュボード機能を指す表記は全てユーザー向け文言を統一する対象：
  - `app/views/growth_dashboards/index.html.erb`
  - `app/views/homes/top.html.erb`（LP「T.T.LOGでできること」⑤番）
  - `app/views/shared/_header.html.erb`（通常ナビ・モバイルナビの説明文2箇所）
  - `app/javascript/controllers/growth_chart_controller.js`（凡例ラベル文字列。`legend: { display: false }`で非表示だが表記整合のため変更）
  - `app/services/growth_dashboard_aggregator.rb`（先頭コメント内の言い回しのみ「得点構成比（シェア）」に統一。メソッド名・コメント構造は変えない）
- **i18n化はしない**（リポジトリ全体でビュー本文の日本語はi18nキー化されていない現状の流儀を踏襲し、スコープを広げない）
- **コード内部識別子（`share`キー、`monthly_usage_share_series`、`calculate_share`等）はリネームしない**。`share`は「シェア（構成比）」として技術的に正確であり、リネームすると`spec/services/growth_dashboard_aggregator_spec.rb`の多数の`eq`完全一致アサーション（キー名）を全て書き換える必要が生じ、このスプリントの目的に対してコスト・リスクが不釣り合いなため見送る（将来的に識別子も揃えたい場合は別スプリントとする）

### 変更内容
1. `app/views/growth_dashboards/index.html.erb`
   - 見出し: `得点内訳における使用率の推移` → `得点内訳における得点構成比の推移`
   - 免責文: `その月に自分が取った得点のうち対象技術が占める割合（使用率）です。` → `（得点構成比）です。`
   - 空状態メッセージ: `使用率の推移がここに表示されます` → `得点構成比の推移がここに表示されます`
2. `app/views/homes/top.html.erb`: `技術別の使用率を月別・週別に可視化` → `技術別の得点構成比を月別・週別に可視化`
3. `app/views/shared/_header.html.erb`（2箇所）: `使用率` → `得点構成比`
4. `app/javascript/controllers/growth_chart_controller.js`: 凡例ラベル文字列内の `使用率` → `得点構成比`
5. `app/services/growth_dashboard_aggregator.rb`: 先頭コメントの「使用率（シェア）」の言い回しを「得点構成比（シェア）」に統一

### テスト
- `spec/requests/growth_dashboards_spec.rb:42-46` のテストタイトルとアサーションを書き換え:
  ```ruby
  it "「得点率」ではなく得点構成比であることが伝わる表記になっていること" do
    get growth_dashboards_path
    expect(response.body).to include("得点構成比")
    expect(response.body).not_to include("得点率の推移")
  end
  ```
- LP/ヘッダーの文言を直接アサートしているspecがないか事前にgrep確認し、あれば同様に更新する
- `spec/services/growth_dashboard_aggregator_spec.rb` は変更不要（キー名・値を変えないため既存の`eq`アサーションはそのまま通る）

### 検証
- `bundle exec rspec && bundle exec rubocop --parallel`
- ブラウザ確認: ダッシュボード・LP・ヘッダーNEWバッジ説明文のすべてで「得点構成比」表記に揃っていることを目視確認

---

## Sprint 3: 期間別明細テーブルの追加

**ブランチ**: `feature/growth-dashboard-period-detail-table`

### 設計方針
`GrowthDashboardAggregator#monthly_usage_share_series`が既に返している`{ period_label:, share:, score:, total_score:, match_count: }`をそのまま使い、グラフの下に期間別の明細テーブルを追加する。JS側の変更は不要（既存の`@series`のキーで足りる）。

`app/views/match_infos/_batting_score_table.html.erb`のデザイン言語（モバイル用`d-md-none`テーブル／PC用`d-none d-md-table`テーブルの2本切り替え、`table`クラス）を参考にするが、ループ単位が「技術」ではなく「期間」のため既存partialの直接流用はせず、新規partialとして同じ見た目のパターンで作る。

### 変更・新規ファイル
1. 新規: `app/views/growth_dashboards/_period_detail_table.html.erb`
   - `series`をローカル変数として受け取り、各行に「期間・得点構成比(%)・対象技術の得点数・総得点数・集計試合数」を表示
   - レスポンシブな2テーブル切り替え構造を踏襲（列数が少ないため列構成はモバイル/PCで揃えてよい）
2. `app/views/growth_dashboards/index.html.erb`
   - グラフ`div`の直後、`<% else %>`ブロック内に `<%= render "period_detail_table", series: @series %>` を追加（`@series.empty?`のときはテーブルを出さない）

### テスト
- `spec/requests/growth_dashboards_spec.rb` に新規コンテキスト「期間別明細テーブル」を追加
  - 既存の数値例（8月: share 71% / score 10 / total_score 14 / match_count 2 等）に対応する具体的な数値がレスポンスに含まれることを確認
  - 空状態（`@series.empty?`）の場合はテーブルがレンダリングされないことを確認

### 検証
- `bundle exec rspec && bundle exec rubocop --parallel`
- ブラウザ確認: 複数期間分の試合データがある状態でダッシュボードを開き、グラフの折れ線の値とテーブルの数値が一致すること、モバイル幅でもテーブルが崩れず表示されることを確認

---

## 共通の進め方（CLAUDE.md準拠）

各スプリントについて：
1. `main`から最新を取得しブランチを切る
2. 実装（上記ファイルを変更）
3. `bundle exec rspec && bundle exec rubocop --parallel` が緑であることを確認
4. ブラウザでの動作確認
5. 本プランファイル（`plans/1-2-3-tranquil-kite.md`）を実装コミットと同時にコミット
6. ユーザーの指示があればPR作成（`.github/PULL_REQUEST_TEMPLATE.md`使用）
7. PRマージ完了後に次のスプリントのブランチを切る（複数スプリントをまとめてPRにしない）
