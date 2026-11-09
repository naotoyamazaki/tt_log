# 相手得点時に「自分の凡ミス」を選択可能にし、技術別の失点数として集計する

## Context
現状のラリー入力は「誰が得点 → どの技術で」の2ステップで、相手得点時も選ぶのは相手が決めた技術のみ。
自分の凡ミス（ドライブをネットに引っ掛けた等）で失点しても記録できず、「どの技術でミスが多いか」が分析できない。
相手得点のステップで「相手の好プレー」/「自分の凡ミス」を選べるようにし、凡ミスは自分の技術の失点として集計・表示・AI分析に反映する。
自分の得点側の打法選択は変更しない。

## ロジック上の指摘（要確認・本プランで対処済み）
1. **`lost_score` の意味衝突**: 現状 `lost_score` = 「相手がその技術で得点した数」。凡ミスを同じ列に入れると、相手の得点技術ランキング
   （`opponent_scoring_techniques`）に「自分のミス技術」が混入し、AI向けの「相手得点」も汚れる。→ **別カラム `own_error_count` を新設**し `lost_score` は相手の好プレー専用のまま維持する。
2. **ゲームスコア**: `Game#recalculate_scores`（`game.rb:12`）は `scores.sum(:lost_score)` で opponent_score を再計算している。凡ミスは相手の1点なので
   `lost_score + own_error_count` の合計にしないと、編集後にスコアが減る。
3. **指標の定義（ミス率は採用しない）**: 既存の得点率 = `score / (score + lost_score)` は「自分の技術」と「相手の技術」が混ざった指標（`GrowthDashboardAggregator` 冒頭コメントにも制約あり）。
   入力は「ラリーを決めた最後の1打」のみで技術ごとの使用回数が分からないため、`ミス ÷ (得点 + ミス)` は「使用時のミス率」にならず誤解を招く。
   → 既存率は変えず、凡ミスは **ミス数と、全凡ミスに占める割合(share)** のみ表示する（既存の相手得点技術ランキングと同じ形式）。「サンプル少」注記も不要。
4. **サーブミスの二重性**: 「自分の得点」で選ぶサーブミス＝相手のサーブミス、「自分の凡ミス」で選ぶサーブミス＝自分のサーブミス。意味が逆なので集計・表示で混同しないよう、
   サーブミスは `own_error`（自分側）のみ凡ミス集計対象とし、`player` 勝ちのサーブミスは従来どおり。「相手の好プレー」ボタンからは除外（ユーザー決定）。
5. **AI除外ルール**: `RallyContextBuilder::EXCLUDED_STYLES`（net_or_edge, serve_miss）は凡ミスにも適用するか要判断。
   → net_or_edge は除外維持、**serve_miss の自分の凡ミスは除外しない**（自分のミスなので改善アドバイス対象。システムプロンプト52行の記述も更新）。
6. **後方互換**: `point_type` のデフォルトは `normal` で既存ラリーは影響なし。過去データの移行はしない（ユーザー決定）。
7. **未カバーの経路**: 旧形式（`game_scores`）、編集画面 `_form_edit`、中断/undo復元（`extract_partial_data_from_game`、`reconstruct_partial_data`）、
   autosave(localStorage) も新フィールドを通す必要がある。漏れると凡ミスが相手の好プレーとして復元される。

## DB（要マイグレーション）
- `rallies.point_type` integer, null:false, default 0（enum: `normal: 0`, `own_error: 1`。player勝ちは常に normal）
- `scores.own_error_count` integer, null:false, default 0
- マイグレーション適用後は CLAUDE.md の手順どおり `heroku run bin/rails db:migrate` → `db:migrate:status` 確認 → `heroku ps:restart web` を必ず実施。

## 変更内容
### モデル
- `app/models/rally.rb`: `enum :point_type`、`own_error` は winner が opponent のときのみ有効とするバリデーション。
- `app/models/score.rb`: `own_error_count` 追加。
- `app/models/game.rb:9-14`: `opponent_score` = `sum(:lost_score) + sum(:own_error_count)`。

### 入力UI
- `app/views/match_infos/_rally_input.html.erb`: 「相手の得点」選択後に **ステップ1.5「相手の好プレー / 自分の凡ミス」** を追加。ステップ2の見出しは文脈で切替（「どの技術で得点された？」/「どの技術をミスした？」）。
- `app/javascript/controllers/rally_input_controller.js`:
  - `selectWinner`(88行): opponent の場合は点種別選択ステップへ。
  - 新 `selectPointType`、`selectStyle`(94行) で `rallies.push({winner, batting_style, point_type})`。
  - `renderStyleButtons`(166行): 相手の好プレー時は `serve_miss` を除外。
  - `renderRallyList`(177行) と `undo` に点種別表示（例「相手 / 自分のミス: フォアドライブ」）、`serializeRallies` に point_type を含める。
- `app/assets` 側のCSS（`DESIGN.md` 参照）: 点種別ボタンのスタイル追加。

### コントローラー（`match_infos_controller.rb`）
- `persist_rally_records`(437行) に `point_type`（不正値は normal にフォールバック）。
- `aggregate_scores_from_rallies`(442行): `(style, point_type)` で集計し、`lost_score`（opponent & normal）と `own_error_count`（opponent & own_error）を分けて保存。
- `extract_partial_data_from_game`(398行) に point_type、`reconstruct_partial_data`(448行) に own_error_count を追加。
- strong params（`scores_attributes` 2箇所）に `:own_error_count`。

### 集計・表示
- `app/helpers/application_helper.rb`: `opponent_scoring_techniques` は従来どおり `lost_score` のみ（凡ミス混入なし）。
  新 `own_error_techniques`（own_error_count 降順、同数は技術の固定順。各行に ミス数 と 全凡ミスに占める share(%)）を追加。`player_scoring_techniques`(45-50行) と同じ構造で実装。
- `app/views/match_infos/_match_info_detail.html.erb:47-75` と `_batting_score_table.html.erb`: **試合全体**の「自分の凡ミス技術ランキング」セクション追加（テーマ色は DESIGN.md に従う）。
- `app/views/match_infos/_game_score_breakdown.html.erb`: **ゲーム別**にも「自分の凡ミス技術ランキング」を追加（試合全体と同じ `own_error_techniques` ヘルパーをゲーム単位のscoresに適用）。
- `app/views/match_infos/_score_progression.html.erb`（得点推移表）: 相手得点セル(46-50行)で `point_type == own_error` のラリーは略称に「✕」を付けて表示（例 `FD✕`）し、相手の好プレーと色を変える（DESIGN.md 準拠のCSS追加）。
  `show.html.erb:67-73` の略称モーダルに凡ミス表記（✕＝自分の凡ミス）の凡例を追加。凡ミスのラリーが相手の得点技術に見える誤表示を防ぐ。
- `app/views/match_infos/_form_edit.html.erb` / `scores/_score_fields.html.erb`: 「凡ミス数」入力追加、`scoreboard_controller.js:80,138` の失点合計に加算。

### AI分析
- `app/services/rally_context_builder.rb`: `technique_stat`(95-107行) で相手得点を `winner == opponent && normal` に限定、新セクション【自分の凡ミス（技術別ミス数）】を追加。`game_flow_text`/`technique_top3`/連続失点分析も点種別を考慮。
- `app/services/chatgpt_service.rb`: システムプロンプト(45-54行)に「自分の凡ミスと相手の好プレーの違い」を追記、`advice_format_instruction`(130-141行) の弱点項目に凡ミス多発技術を反映。`rally_stats_text`(111-128行) に新セクションを追加。
- 【自分の凡ミス】セクションの内容:
  - 凡ミス数の多い**上位3技術のみ**を「技術名: N件（凡ミス全体の X%）」形式で出力（文章を長くしないため）。全技術の詳細は画面の凡ミスランキングを参照とする。
    ミス率（使用時の失敗割合）は使用回数が不明なので出力しない。凡ミス0件の試合ではセクション自体を出さない。
  - システムプロンプトの方針: 凡ミスは「自分のミスで失った点」であり、相手の好プレー（相手の得点技術）とは別物として扱い混同しない。
  - **ミス原因を推測しない**: 凡ミスが多い技術について、精度の問題かリスクの取りすぎかなどの原因をAIが断定・推測してはいけない。
    代わりに「ミスが多い技術として事実を伝え、原因（精度かリスクの取りすぎか等）はユーザー自身が試合映像を見返して確認するよう促す」文言にする。
- 旧 `MatchInfo#batting_score_data`（55-57行, 105行）は「凡ミス」列を追記。
- 成長ダッシュボード(`growth_dashboard_aggregator.rb`)は自分の得点のみ使用のため変更なし（スコープ外）。

## スプリント分割案（CLAUDE.md: 1スプリント=1ブランチ=1PR、マージ後に次へ）
1. **S1 データ層**: マイグレーション、モデル、Game再計算、コントローラー保存/集計/復元、spec。
2. **S2 入力UI**: rally_input（ステップ・JS・CSS）、編集フォーム、autosave、request/system spec。
3. **S3 表示・AI**: ヘルパー、ランキング表示（試合全体・ゲーム別）、得点推移表の凡ミス表示と略称モーダル凡例、RallyContextBuilder、ChatgptService、spec。

## 検証
- `bundle exec rspec && bundle exec rubocop --parallel`
- 追加spec: Rally/Score/Game(合算)、`match_infos` request（point_type付きrallies POST → lost_score/own_error_count分離、不正値フォールバック）、
  helper（own_error_techniques、opponent側に凡ミス非混入）、RallyContextBuilder（新セクション・serve_miss扱い）、ChatgptService（プロンプト文言）。
- 手動(Playwright, 使い捨てテストユーザー): 相手得点→凡ミス→技術選択→ゲーム終了→show で凡ミスランキング表示（試合全体・ゲーム別）、得点推移表の「✕」表示と凡例、ゲームスコア整合、undo/中断再開で復元、編集画面。
- 本番: マイグレーション適用 + dyno再起動。
