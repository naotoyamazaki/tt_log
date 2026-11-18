# Phase 2（改訂版）: AI基盤改善 → 月間レポート＋練習提案 → 利用計測

## Context

旧Phase 2プラン（`77-phase-0-...-zippy-hanrahan.md`）は「長期メモリ中心」だったが、現在の実装（凡ミス機能の追加、
`analysis_type` が2種類、既存AI呼び出しの失敗キャッシュ問題）と、Codexによる見直し
（`monetization-phase-2-revised-handoff.md`）を踏まえて再構成した。

**採用方針（ユーザー判断済み）**: 相反点はすべて引き継ぎ書を優先。

| 論点 | 決定 |
| --- | --- |
| 長期メモリ | **当面実装しない**（コード・DB・UIとも作らない。ChatgptServiceに `memory:` 引数も追加しない） |
| Sprint 1 | **既存の両AI分析（技術 / サーブ・レシーブ）も含めて基盤改善**（失敗文言の非保存・再試行・時間予算・同時生成防止・使用量計測） |
| 再生成条件 | 追加だけでなく編集・削除・月移動・下書き完了・前月データ変更もすべて検知 |
| API障害の検証 | キー改ざんは行わず、スタブ／ローカル疑似サーバーで隔離して行う |

旧プラン2本と引き継ぎ書は履歴として保持（編集しない）。**本プランが Phase 2 の実装順序・要件の正**。
課金（Stripe等）は本プランの範囲外。

## 全Sprint共通の分析原則（プロンプト・画面・テストで厳守）

- 技術の「得点構成比」を成功率・使用頻度と混同しない／構成比の増加だけで「上達した」と断定しない
- 得点・相手の好プレー・自分の凡ミスを区別。凡ミスの原因・記録にない相手技術を創作しない
- 技術分析とサーブ・レシーブ分析は分母を混ぜない。各指標に対象試合数・ポイント数・期間を明示
- 勝敗不明・戦型未設定・前月なし・データ不足をゼロや敗北に置き換えない
- 凡ミス記録導入前の0を「ミスなし」と解釈しない（Sprint 2で比較可能範囲を定義）
- 練習提案（AI）と実際に取り組んだ練習を区別。結論・提案は画面上の集計値で説明できること

## 再利用する既存実装

| 用途 | 場所 |
| --- | --- |
| 既存AI呼び出し（置換対象） | `app/services/chatgpt_service.rb`（`get_advice` / `get_serve_receive_advice`） |
| アドバイス生成フロー | `app/controllers/match_infos_controller.rb#show`（14-28行） |
| 失敗文言定数の元 | `chatgpt_service.rb:80,84,249`（`"アドバイスの取得に失敗しました。"`） |
| 技術構成比 | `app/services/growth_dashboard_aggregator.rb`（1技術ずつ → `Score.allowed_batting_styles` をループ、`includes(:scores)`） |
| 戦型別勝率 | `app/services/opponent_type_win_rate_aggregator.rb` |
| サーブ・レシーブ集計 | `ServeReceiveAnalyzer.new(patterns: ...)`（`opponent_type_analyses_controller.rb` の使い方） |
| 凡ミス | `Score#own_error_count`、`Rally#own_error?`、`RallyContextBuilder#own_error_text` |
| 勝敗 | `MatchInfo#result` / `#game_count_score`、`MatchInfo.human_enum_name` |
| ビュー骨格 | `show-container fade-in-up` / `section-card` / `advice-section` / `stat-summary-row` |
| パラメータ検証の型 | `growth_dashboards_controller.rb`（`resolve_*` ホワイトリスト） |
| ナビ | `app/views/shared/_header.html.erb`（PC 13-38行 / モバイル 40-68行の2箇所） |
| spec | `spec/requests/growth_dashboards_spec.rb`、`spec/support/login_macros.rb`、`spec/services/chatgpt_service_spec.rb`（`Net::HTTP.post` スタブ方式 → 新クライアント用に更新） |

---

## Sprint 1 — 既存AIを含む基盤改善（`feature/sprint-1-ai-foundation`）

**目的**: 現行の試合アドバイスを安定させ、新機能の原価・失敗を把握できる土台にする。

### 1. `OpenaiClient`（新規 `app/services/openai_client.rb`）
- `OpenaiClient.chat(feature:, system:, user:, json: false, max_completion_tokens:, temperature: nil, timeout:)` → `Result`（`success?` / `content` / `error_kind` / `usage` / `duration_ms`）。例外は投げない
- `Net::HTTP.start`（`open_timeout: 3, write_timeout: 5, read_timeout: timeout`）。**自動リトライなし**。
  read_timeout は受信ごとにリセットされるため、外側にも全体デッドラインを設ける（合計で **24秒以内**、Heroku 30秒に余裕）
- 空content・非2xx・JSON不正・タイムアウトはすべて失敗として返す（`error_kind`: timeout / http_error / empty / parse など）
- モデルは定数（現行 `gpt-5.4-mini` を維持）。パラメータは新モデル仕様の `max_completion_tokens` を使用。**着手時にOpenAI公式仕様で互換性を再確認**（temperature・json_object 対応）
- ログはステータス・処理時間・トークン数のみ。**プロンプト・本文・APIキーは出さない**（既存の全文ログ出力を削除）
- テスト用に `OPENAI_API_URL` で接続先を上書き可能にする（未設定なら本番URL）。ローカル疑似サーバーでの障害検証用

### 2. 使用量記録 `AiUsageLog`
- migration `CreateAiUsageLogs`: `user_id`（nullable FK）, `match_info_id`（nullable）, `feature`（string: match_advice / serve_receive_advice / monthly_report）, `model`, `success`（bool）, `error_kind`, `duration_ms`, `prompt_tokens` / `completion_tokens` / `total_tokens`（**取得不能は NULL**＝0と区別）, `created_at`。`user_id, feature, created_at` に index
- `OpenaiClient` 呼び出し側（または client 内）で1呼び出し1行を記録。記録失敗でAI結果を壊さない（rescueしてログのみ）

### 3. 失敗の非保存・再試行・同時生成防止
- migration `AddAdviceStateToMatchInfos`: `advice_generating_at`（datetime, null）, `advice_failed_at`（datetime, null）
- 新規 `app/services/advice_generator.rb`: `call(match_info)` が `analysis_type` で分岐し ChatgptService を呼ぶ
  - **claim**: `UPDATE ... SET advice_generating_at = now WHERE id = ? AND (advice IS NULL/失敗文言) AND (advice_generating_at IS NULL OR advice_generating_at < now - 45s)` の影響行数で排他（DB行ロックを長時間保持しない）。claim失敗＝他リクエスト生成中 → 「生成中です。しばらくして再読み込みしてください」を表示
  - 成功時のみ `advice` 保存・`advice_failed_at` クリア。失敗時は `advice` 不変、`advice_failed_at` 設定。いずれも `advice_generating_at` を解除（ensure）
- `ChatgptService`: `OpenaiClient` を使うよう置換、**失敗時は文言ではなく `nil`（または失敗Result）を返す**。プロンプト生成ロジックは変更しない
- `MatchInfosController#show`: 保存済み有効アドバイスがあれば再利用。無く、かつ `advice_failed_at` が無ければ自動生成（現行の初回表示挙動を維持）。失敗済みなら自動再生成せず（リロード連打による課金増を防ぐ）エラーカード＋「もう一度生成する」ボタン
- 新ルート `post :generate_advice`（member）で明示再試行（`set_match_info` による current_user スコープを維持。他ユーザーは404）
- **既知の失敗文言の回復**: `MatchInfo::LEGACY_FAILURE_ADVICE` と完全一致する `advice` は「未生成・失敗」として扱う（読み取り時判定、DB一括更新はしない）。再試行成功で上書き。正常アドバイスは一切変更しない
- Stimulus `loading_button_controller.js`（新規）: 送信で無効化＋「生成中…」表示（Sprint 2 でも流用）
- 失敗時も試合データ・基本分析は表示

### 4. 確認事項（着手時）
- `update` 時に `advice` が再生成されない現状（編集可能な項目が分析内容に影響するか）を確認。影響する項目があれば無効化条件を計画に追加、無ければ現状維持を明記
- `set_match_info` のユーザースコープ確認（`edit` は `MatchInfo.find` 直叩きのため、IDOR有無を確認。あれば別途報告）
- 本番デプロイ: 追加カラムのため **マージ後 `git push heroku main` → 即 `heroku run bin/rails db:migrate` → `db:migrate:status` 全up → `heroku ps:restart web`**（CLAUDE.md の過去インシデント手順）。適用までの間は新カラム参照で500になり得る点をPR説明に明記

### テスト
- `openai_client_spec`: 成功 / 非2xx / 空content / `Net::ReadTimeout` / 不正JSON / usage有無（NULL） / ログに本文が出ない / jsonフラグ
- `advice_generator_spec`: 成功保存 / 失敗で非保存・`advice_failed_at` / claim競合で2回目は呼ばない / 古いclaim（45秒超）は再取得 / legacy文言の回復 / 両 analysis_type
- 既存 `chatgpt_service_spec` を新クライアント前提に更新（プロンプト内容の既存assertionは維持）
- request spec: show（正常再利用・失敗表示・自動再生成しない）、`generate_advice`（他ユーザー404・未ログイン）
- 使用量: 成功/失敗が `AiUsageLog` に記録される

### 完了条件
- 両分析フローで正常アドバイスを表示・再利用。エラー/タイムアウト/空応答は保存されない
- 失敗後に再試行可能、保存済み失敗文言からも回復可能
- 本文・秘密情報がログに出ない。使用量取得不能はNULL
- **時間予算（24秒デッドライン）と同時生成防止の検証結果を報告**（疑似サーバーで遅延・無応答を再現）

---

## Sprint 2 — 月間レポート＋根拠付き練習提案（`feature/sprint-2-monthly-report`）

**前提**: Sprint 1 のPRがマージ済み、かつユーザーの明示指示があること。着手時に最新コードで再確認。

### データ
- migration `CreateMonthlyReports`: `user_id`（FK, null:false）, `month`（date, 月初, null:false）, `content`（jsonb, **null可**＝未成功の行を許容）, `input_fingerprint`（string）, `match_count`（integer）, `generated_at`, `generating_at`（claim用）, `last_attempt_at`, `last_failed_at`。unique index `[:user_id, :month]`（create_table外）
- 長期メモリ関連のテーブル・カラムは作らない

### 入力集計 `MonthlyReportInputBuilder`（新規）
- 対象: `current_user.match_infos.completed` かつ `match_date` が対象月。**生成に使う集計値のみ**を一つのHash（＝プロンプトの根拠＝画面の数値＝fingerprintの元）にまとめる
  - 試合数・勝敗（勝敗不明は別カウント）／前月との差（前月データが無ければ「比較なし」）
  - 技術の得点構成比（`GrowthDashboardAggregator` を全技術でループ。対象は `technique` タイプのみ、「自分の全得点（receive除く）に占める割合」と明記）
  - 凡ミス傾向（`Score#own_error_count` 上位技術）。**凡ミス記録導入日以降に作成された試合のみ**を比較・集計対象とし、導入前を含む月は「比較不可」と表示。導入日の定数は着手時に本番の読み取り専用クエリで確定（`20261107000001` のデプロイ日を確認）
  - 戦型別勝率（`OpponentTypeWinRateAggregator`、戦型未設定は除外し件数を明示）
  - サーブ・レシーブ傾向（`serve_receive` タイプのパターンのみ `ServeReceiveAnalyzer(patterns:)`）
  - 各項目に対象試合数・対象ポイント数を付与。データが無い項目は「対象なし」として載せない
- 選手名・相手名・メール等の個人情報は入力に含めない
- **生成条件**: 対象月の完了試合のうち、分析可能データ（technique=scoresあり / serve_receive=patternsあり）を持つものが2試合以上。「2試合で傾向が確定」とは表示せず、少数データの注意書きを付ける
- 当月は「途中経過」と明示、未来月は生成不可

### 更新検知（fingerprint方式）
- 入力Hash（対象月＋比較に使う前月分）を正規化して SHA256 → `input_fingerprint`。`updated_at` 比較には依存しない
- 表示時に現在の入力から fingerprint を再計算し、保存値と比較して状態を決定: **未生成 / 最新 / 更新あり（対象データ変更）**
- 追加・編集・削除・日付の月移動・下書き完了・前月データ変更は、すべて集計値の変化として検知される
- **生成中にデータが変わった場合**: fingerprint は「AI呼び出し前に計算した値」を保存する。完了後の現在値と異なれば「更新あり」と表示され、古い結果が最新扱いされない
- 削除等で生成条件（2試合）を割り込んだ月は、保存済みレポートを「対象データが変わったため古い内容です（生成時点: ○○）」と表示し、再生成は不可（条件未達メッセージ）

### 生成 `MonthlyReportGenerator`（新規）
- `OpenaiClient.chat(feature: "monthly_report", json: true, max_completion_tokens: 1500, timeout: 20)`。全体デッドライン内
- 出力JSON: `{ summary, highlights[], issues[], practice_menu: [{ title, reason, minutes }] }`
- `MonthlyReportContentValidator`: 必須キー・型・件数（highlights/issues は妥当な上限、practice_menu 1〜3件）・文字数・`minutes` が妥当な整数・`reason` 非空を検証。不合格は**保存しない**
- プロンプトに共通分析原則（上記）を明記: 構成比≠成功率、上達の断定禁止、凡ミス原因・ネット/エッジ・記録外の相手技術に言及禁止、各 `reason` は入力の具体的数値を引用、データ不足項目は断定しない
- 成功時のみ `content` / `generated_at` / `input_fingerprint` / `match_count` を更新。**失敗時は既存の有効な保存結果を壊さず** `last_failed_at` のみ更新（古い内容表示時は生成時点を明示）

### 同時生成防止・回数制限
- Sprint 1 と同様の atomic UPDATE による `generating_at` claim（行が無い場合は `create_or_find_by` ＋ unique index で競合吸収、45秒で失効）
- 再生成の最小間隔 **60秒**（`last_attempt_at`）／ユーザーあたり **1日5回**まで（`AiUsageLog` の monthly_report 成功+失敗件数で判定）。数値は定数化し、Sprint 3 の実測で見直す前提
- 「更新あり」でないのに再生成は不可（保存済みを表示）

### 画面・ルーティング
- `resources :monthly_reports, only: [:index, :show, :create], param: :month`
- `index`: 完了試合のある月の一覧（試合数、状態バッジ: 未生成 / 最新 / 更新あり）
- `show`: `month` は `\A\d{4}-(0[1-9]|1[0-2])\z` で厳格にパース（不正は index へ）、未来月は不可。生成済み→表示、未生成→対象試合数と生成条件つき「生成する」ボタン
- `create`: 条件・間隔・回数・claim を確認 → 生成 → show へ。失敗は flash＋再試行可
- ビューは `.show-container` / `.section-card` / `.advice-section` / `.stat-summary-row`、練習提案はカードリスト。各提案に根拠（`reason`）と目安時間。「AIの提案であり実施記録ではない」旨を表示
- `app/views/shared/_header.html.erb` の **PC・モバイル2箇所**に「月間レポート」を追加（NEWバッジは既に2つあるため付けない）
- `loading_button_controller.js`（Sprint 1で作成済み）を流用

### テスト
- `MonthlyReportInputBuilder`: 少数データ／前月なし／勝敗不明／戦型未設定／技術・SR混在／凡ミス導入前後／個人情報を含まない
- `MonthlyReportGenerator`・Validator: nil・JSON不正・キー欠落・件数超過・正常・失敗時に既存content維持・生成中にデータ変更で「更新あり」
- 更新検知: 追加・編集・削除・月移動・下書き完了・前月変更の各ケースで fingerprint が変わる／変わらない
- request spec: 未ログイン・不正month・未来月・他ユーザーのレポート不可（404/リダイレクト）・間隔/日次上限・同時claim・create成功/失敗
- OpenAI は `allow(OpenaiClient).to receive(:chat)` でスタブ

### 完了条件
- 通常生成 / 保存済み閲覧 / 変更後の再生成 / 失敗後の再試行
- 練習提案の根拠と画面上の数値が矛盾しない
- 本番デプロイは Sprint 1 と同じmigration手順（適用確認＋dyno再起動）

---

## Sprint 3 — 利用計測と軽いフィードバック（`feature/sprint-3-report-feedback`）

**前提**: Sprint 2 マージ済み＋ユーザー指示。**詳細計画は Sprint 2 完了後に最新コードで具体化する**（以下は骨子）。

- `ReportFeedback`（user, monthly_report, rating: helpful/not_helpful。本人のみ作成・変更可、1ユーザー1レポート1件）
- 「取り組む課題」選択（意図の記録のみ。実施の証拠として扱わない、画面でも区別）
- 計測は**サーバー側の `UsageEvent`**（report_generated / report_viewed 等。`dedupe_key` unique で再読み込みの二重計上を防止）。外部解析（GA）にレポート本文・選手名・メール等は送らない
- 初回試合登録・2試合目到達・翌月継続は DB クエリから導出（イベント不要）。各指標の対象者・期間・分母を文書化
- AI原価集計は `AiUsageLog` を使い、rake task（例 `ttlog:ai_usage_report`）で成功/失敗/再生成別に出力。管理画面は作らない
- 完了時に評価期間・件数・未検証事項を報告

## 範囲外（今回やらない）
長期メモリ全般・課金基盤（Stripe）・価格/無料回数の確定・Scheduler/worker・自動月次配信。メモリを再検討する場合は引き継ぎ書の「再検討条件」（時系列整合・再構築・同時更新・リセットUI同時提供 等）を満たす別プランとする。

## 進め方・共通ルール（CLAUDE.md準拠）
- スプリントごとに新ブランチ。**PR作成はユーザー指示後**、次Sprintは前PRマージ＋ユーザー指示の両方が必要
- plans ファイル（本プラン・引き継ぎ書・旧プラン）は **Sprint 1 の実装コミットと一緒にコミット**（未追跡のまま残さない）
- 実装後 `bundle exec rspec && bundle exec rubocop --parallel`（行長120 / メソッド20行 / クラス200行）
- generator → evaluator の順。ログイン検証は使い捨ての新規テストユーザーのみ。API障害の検証はスタブ／疑似サーバー（`OPENAI_API_URL`）で隔離し、共有・本番のAPIキーは変更しない

## 検証（各Sprint共通＋固有）
1. `bundle exec rspec && bundle exec rubocop --parallel` 緑、`curl -s -o /dev/null -w "%{http_code}" http://localhost:3000` が 200
2. Sprint 1: 疑似サーバーで 正常 / 5xx / 空応答 / 30秒無応答 を再現し、画面200・失敗非保存・再試行成功・合計24秒以内を確認。連打・2タブ同時で生成が1回だけ。`AiUsageLog` と本文なしログを確認
3. Sprint 2: 新規ユーザーで試合を2件以上登録（技術・SR混在、下書き完了含む）→ 生成 → 再閲覧でAI未呼び出し → 試合の編集/削除/月移動後に「更新あり」→ 再生成 → 失敗スタブで旧内容保持。1試合のみの月・未来月・不正monthの挙動
4. 未検証の項目（本番原価・実利用者数など）は完了報告で未検証と明記
