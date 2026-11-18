# Phase 2: AI長期メモリ ＋ 月間成長レポート ＋ 練習メニュー提案

## Context（なぜこの実装をするのか）

Phase 0（成長ダッシュボード）・Phase 1（対戦相手タイプ＋タイプ別分析）で「複数試合をまたいだ集計」の基盤が整った。
Phase 2 では、その蓄積データを **自分専用AIコーチ** として活かし、継続利用の動機（継続率）を底上げする。
Phase 3（課金）で premium 機能になる想定の「長期推移・AI履歴・成長レポート」の中身をここで作る。

ユーザー確認済みの方針:

- **AI長期メモリ**: ユーザー単位の要約1件を保持し、試合アドバイス生成時にプロンプトへ差し込む（トークン増が一定で低コスト）
- **月間成長レポート**: 月を選んで **ボタン押下でオンデマンド生成**、DBに保存（worker dyno / Scheduler は使わない）
- **練習メニュー提案**: 月間レポートの1セクションとして、同じAI呼び出しで一緒に出力（API呼び出しは1回）

## 現状調査で判明した制約（設計に反映）

| 事実 | 影響 |
| --- | --- |
| OpenAI呼び出しは `Net::HTTP.post` 直叩き、**タイムアウト未設定**（既定60秒 > Heroku 30秒）`chatgpt_service.rb:67` | 新規呼び出しは明示的にタイムアウトを設定 |
| 失敗時も `"アドバイスの取得に失敗しました。"` を返し、そのまま `match_info.advice` に保存されて**再生成されない** | 新規コードは失敗を `nil` で返し、**保存しない** |
| リクエスト/レスポンス全文を `Rails.logger.info` 出力（`chatgpt_service.rb:65,71`） | メモリ・レポートでは個人データ肥大を避け、本文をログに出さない |
| `response_format` 未使用でプレーンテキスト返却 | レポートは JSON モードで構造化出力 |
| `GrowthDashboardAggregator` は技術の**構成比（シェア）**しか出せない（`Score#score/#lost_score` の制約） | レポート内で「技術の成功率」とは言わない。構成比・得点率の表現を厳守 |
| 非同期基盤なし、`lib/tasks` 空 | 同期＋オンデマンド＋DBキャッシュで実装 |
| DESIGN.md（Linear風ダーク）は実画面と不一致。実画面は緑基調の `--tt-*` 変数 | 新ビューは既存の `.show-container` / `.section-card` / `.advice-section` / `.stat-summary-row` に合わせる |

## 再利用する既存実装

| 用途 | 流用元 |
| --- | --- |
| 月内の試合抽出 | `current_user.match_infos.completed`（`MatchInfo` scope） |
| 技術構成比の月次集計 | `app/services/growth_dashboard_aggregator.rb` |
| 相手タイプ別勝率 | `app/services/opponent_type_win_rate_aggregator.rb` |
| サーブ・レシーブ集計（複数試合） | `ServeReceiveAnalyzer.new(patterns: ...)`（`opponent_type_analyses_controller.rb:48` の使い方） |
| 勝敗・ゲームカウント | `MatchInfo#result` / `#game_count_score` |
| 日本語名 | `MatchInfo.human_enum_name(:opponent_playstyle, key)` / `Score.human_enum_name` |
| ビュー外枠・AI文表示 | `show-container fade-in-up` + `section-card` + `advice-section`（`match_infos/show.html.erb`） |
| 数値サマリ | `.stat-summary-row`（`opponent_type_analyses/show.html.erb`） |
| 認可・パラメータ検証パターン | `growth_dashboards_controller.rb`（`resolve_*` ホワイトリスト） |
| ナビ導線 | `app/views/shared/_header.html.erb`（PC 13-38行 / モバイル 40-68行の**2箇所**） |
| request spec の型 / ログイン | `spec/requests/growth_dashboards_spec.rb`、`spec/support/login_macros.rb` |

---

## Sprint 1 — AI呼び出し基盤（`feature/sprint-1-openai-client`）

**目的**: 長期メモリ・レポートが安全に使える OpenAI クライアントを用意する（既存 `ChatgptService` の挙動は変えない）。

- `app/services/openai_client.rb` 新規
  - `OpenaiClient.chat(system:, user:, json: false, max_tokens:, timeout: 20)` → 成功時は文字列、**失敗・非2xx・タイムアウト時は `nil`**
  - `Net::HTTP.start(..., open_timeout: 5, read_timeout: timeout)`。モデルは `gpt-5.4-mini`（定数。`ChatgptService` と同値）
  - `json: true` で `response_format: { type: "json_object" }`
  - ログはステータスと所要時間のみ（本文は出さない）
- `spec/services/openai_client_spec.rb`: 成功 / 非2xx → nil / `Net::ReadTimeout` → nil / json フラグがボディに入ること
- `ChatgptService` は触らない（Sprint 2 でメモリ引数のみ追加）

## Sprint 2 — AI長期メモリ（`feature/sprint-2-coaching-memory`）

**データ**
- migration: `CreateCoachingMemories` — `user_id`(references, null: false, unique), `summary`(text, null: false, default: ""), `matches_covered`(integer, default 0), timestamps
- migration: `AddMemoryAppliedAtToMatchInfos` — `memory_applied_at`(datetime, null: true)（同一試合の二重反映防止）
- `app/models/coaching_memory.rb` 新規、`User has_one :coaching_memory, dependent: :destroy`（※ `User` は `match_infos` が `restrict_with_error` なので削除時の整合を spec で確認）

**ロジック**
- `app/services/coaching_memory_updater.rb` 新規: `call(user, match_info)`
  - 入力: 現在の `summary` ＋ 今回のアドバイス本文 ＋ 試合の要点（結果・相手タイプ）
  - `OpenaiClient.chat` で「400字以内の更新版サマリ（強み・課題・取り組み中のテーマ・最近の変化）」を生成。**`nil` なら何も更新しない**
  - 成功時のみ `summary` 更新、`match_infos.memory_applied_at` を設定。`memory_applied_at` が既にある試合はスキップ
- `ChatgptService.get_advice(match_info, memory: nil)` / `get_serve_receive_advice(..., memory: nil)`: `memory` があれば user メッセージ冒頭に `【この選手の過去の傾向（要約）】` を追加。無ければ従来と完全に同一（後方互換、既存 spec を壊さない）
- `MatchInfosController#show`（`match_infos_controller.rb:10-29`）: アドバイス生成直前に `current_user.coaching_memory&.summary` を渡し、**生成成功後**に `CoachingMemoryUpdater` を呼ぶ。メモリ更新の失敗は握りつぶし表示に影響させない
  - ⚠ 同一リクエスト内で最大2回のAI呼び出しになる。メモリ更新は `timeout: 10` に制限し、30秒制限を超えないようにする（超過リスクが出たら Turbo Frame 遅延ロードへ切替）
  - 既存の「失敗文言がキャッシュされる」問題には本Sprintでは触れない（スコープ外。必要なら別PR）。ただしその失敗文言はメモリ更新の入力にしない（文言一致でスキップ）

**ユーザー管理**
- メモリ閲覧・リセットUI: 月間レポート一覧ページ（Sprint 3）に「コーチの記憶」カードを置き、内容表示＋「リセット」ボタン（`DELETE /coaching_memory` → `resource :coaching_memory, only: [:destroy]`）。**この導線は Sprint 3 で画面と一緒に配置**し、Sprint 2 ではルート＋コントローラ＋spec まで

**テスト**
- model spec、`CoachingMemoryUpdater` spec（`OpenaiClient` をスタブ。成功更新 / nil で不変 / 二重反映しない）、`ChatgptService` spec（memory あり/なしでプロンプト差分）、`match_infos` request spec（メモリが渡される・更新失敗でも200）

## Sprint 3 — 月間成長レポート＋練習メニュー（`feature/sprint-3-monthly-report`）

**データ**
- migration: `CreateMonthlyReports` — `user_id`(references, null: false), `month`(date, null: false, 月初), `content`(jsonb, null: false), `match_count`(integer, null: false), `generated_at`(datetime, null: false), timestamps。`add_index [:user_id, :month], unique: true`（create_table 外）
- `app/models/monthly_report.rb`: `belongs_to :user`、`content` の必須キー検証（`summary` / `highlights` / `issues` / `practice_menu`）

**ロジック**
- `app/services/monthly_report_context_builder.rb` 新規: 対象月の `completed` 試合から整形テキストを生成
  - 試合数・勝敗・前月比 / 技術構成比（`GrowthDashboardAggregator`、「成功率」とは書かない）/ 相手タイプ別勝率（`OpponentTypeWinRateAggregator`）/ サーブ・レシーブ傾向（`ServeReceiveAnalyzer`）/ 長期メモリ要約
  - 全試合の生ログは渡さず**集計値のみ**（トークン抑制）
- `app/services/monthly_report_generator.rb` 新規: `call(user, month)`
  - 対象月の試合が **2試合未満なら生成しない**（理由を返す）
  - `OpenaiClient.chat(json: true, max_tokens: 1500, timeout: 20)`。出力JSON: `{ summary, highlights[], issues[], practice_menu: [{ title, reason, minutes }] }`
  - パース失敗・キー欠落・`nil` は**保存しない**（再試行可能）
  - 成功時 `MonthlyReport` を upsert
- 再生成条件: 既存レポートがある場合、`generated_at` 以降に新しい試合が追加されたときのみ再生成可（無駄なAIコスト防止）。それ以外は保存済みを表示
- 練習メニューは1〜3件、「どのデータ（例: カットマン相手の勝率が低い）に基づくか」を `reason` に必ず含める。プロンプトで「データに無いことは断定しない」「ネット/エッジには言及しない」を明記

**画面・ルーティング**
- `config/routes.rb`: `resources :monthly_reports, only: [:index, :show, :create], param: :month` ＋ `resource :coaching_memory, only: [:destroy]`
- `MonthlyReportsController`（要ログイン）
  - `index`: 試合のある月の一覧（生成済みは✔バッジ）＋「コーチの記憶」カード（内容・リセット）
  - `show`: `month`（`YYYY-MM`）を厳格にパース（不正値は index へ）。未来月は不可。生成済みなら表示、未生成なら「生成する」ボタン
  - `create`: Generator 呼び出し → 成功は show へリダイレクト、失敗は flash でエラー
- ビュー: `.show-container` + `.section-card`。レポート本文は `.advice-section`、数値は `.stat-summary-row`、練習メニューはカードリスト
- `app/javascript/controllers/loading_button_controller.js` 新規（Stimulus）: 送信時にボタンを無効化し「生成中…（10〜20秒ほどかかります）」を表示。二重送信防止
- `app/views/shared/_header.html.erb`: **PC・モバイル2箇所**に「月間レポート」リンクを追加（既存の `badge bg-danger NEW` 流儀）

**テスト**
- service spec（Context/Generator: 2試合未満 / JSON不正 / nil / 成功 / upsert / 再生成条件）、request spec（未ログイン・不正month・未来月・create成功/失敗・他ユーザーのレポートが見えない）、model spec
- OpenAI は `allow(OpenaiClient).to receive(:chat)` でスタブ（既存 `ChatgptService` spec の `Net::HTTP` スタブ方式は Client の spec のみ）

---

## 各Sprint共通の完了条件

- `bundle exec rspec && bundle exec rubocop --parallel` が両方パス（行長120 / メソッド20行 / クラス200行。ビルダー・ジェネレーターは責務分割で収める）
- スプリントごとにブランチ → PR（PR作成はユーザー指示後）。PRはテンプレート `.github/PULL_REQUEST_TEMPLATE.md` を使用。次スプリントは**前PRのマージ後**
- plans ファイルは実装コミットと一緒にコミット
- **migration を含む Sprint 2・3 は、マージ後に本番で `heroku run bin/rails db:migrate` → `db:migrate:status` で全 `up` 確認 → `heroku ps:restart web`**（過去の本番500障害の再発防止）

## 検証方法（end-to-end）

1. `bundle exec rspec && bundle exec rubocop --parallel` 緑
2. `curl -s -o /dev/null -w "%{http_code}" http://localhost:3000` が 200
3. **使い捨ての新規テストユーザー**を作成して Playwright で確認（既存ユーザーのデータ変更は禁止）
   - 試合を3件以上登録 → 各試合の show でアドバイスが出る → 2試合目以降のプロンプトにメモリが入ること（開発ログではなく spec で担保）
   - 月間レポート一覧 → 当月を開く → 生成 → 要約・良かった点・課題・練習メニューが表示される
   - 再度「生成」→ 新試合が無ければ保存済みが表示される / 試合追加後は再生成できる
   - 1試合しかない月では生成不可メッセージ
   - 「コーチの記憶」リセット後、次のアドバイスでメモリ無しになる
4. OpenAI 障害を想定（`OPENAI_API_KEY` を一時的に不正化）してもアドバイス表示が200で返り、レポートが保存されないこと

## 注意点・リスク

- **レイテンシ**: Sprint 2 で show が最大2回のAI呼び出しになる。タイムアウト合計が25秒以内に収まるよう制御し、実測で厳しければ遅延ロードへ変更
- **コスト**: メモリは400字上限・レポートは集計値のみで入力を抑制。再生成は新試合があるときのみ
- **プライバシー**: メモリ・レポート本文をログに出さない。リセット導線を用意
- **範囲外**: 自動月次配信（Scheduler）、メモリの履歴バージョニング、`ChatgptService` の失敗キャッシュ問題の修正、課金による閲覧制限（Phase 3）

---

## 着手前メモ（2026-11-04）

- 本計画は未承認のまま中断。ユーザーからの機能リクエスト対応を優先。
- 再開時は main を最新化し、競合しやすい箇所（`match_infos#show` / `ChatgptService` / `shared/_header.html.erb`（PC・モバイル2箇所）/ `db/schema.rb`）と migration のタイムスタンプを再確認してから Sprint 1 に入る。
- リクエスト機能は CLAUDE.md の方針どおり、別途プランを立てて別ブランチで実装する。
