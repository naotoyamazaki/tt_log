# Sprint 1 実装計画 — 既存AIを含む基盤改善

詳細仕様の正: `plans/monetization-phase-2-revised-handoff-md-rosy-newell.md` の「Sprint 1」節（本ファイルは実装手順への落とし込み）。

## Context
アドバイス生成は `ChatgptService` が失敗時に文言 `"アドバイスの取得に失敗しました。"` を返し、
`MatchInfosController#show` がそれを `advice` に保存してしまう（以後ずっと失敗表示）。タイムアウト管理・同時生成防止・使用量記録もない。
新機能（月間レポート）の前提として、失敗の非保存・再試行・時間予算・使用量計測を整える。

## 現行コードで確認済みの事実
- `show` は `serve_receive?` / 通常で2分岐し、`advice.present?` なら再利用、無ければ同期生成して `update_advice`（失敗文言も保存される）
- `ChatgptService` は `Net::HTTP.post`（タイムアウト指定なし）、プロンプト・レスポンス全文をログ出力。失敗文言は3箇所（80, 84, 249行）
- `edit` は `MatchInfo.find(params[:id])` 直叩き＝**IDOR（他ユーザーの試合が編集画面で見える）**。`set_match_info`（current_user スコープ）が既にあるのに上書きしている。Sprint 1 のスコープ外として報告（修正は1行なので、ユーザー承認があれば同ブランチで対応可）
- `update` は advice を無効化しない。編集可能項目（日付・大会名・メモ・対戦相手属性・スコア）のうちスコア/ゲーム編集は分析内容に影響し得るが、**現状維持**とする（引き継ぎ書の「確認事項」の結論として明記）
- show.html.erb: `@advice` を `simple_format`（通常は常に表示、SRは `present?` のみ）
- Stimulus は `eagerLoadControllersFrom` で自動登録（`loading_button_controller.js` 追加だけでよい）
- spec/services は `chatgpt_service_spec.rb` が `Net::HTTP.post` スタブ方式 → 更新必要

## 実装ステップ（ブランチ: `feature/sprint-1-ai-foundation`）
1. **Migration 2本**: `CreateAiUsageLogs`、`AddAdviceStateToMatchInfos`（`advice_generating_at`, `advice_failed_at`）。`db:migrate` → schema.rb 更新
2. **`app/services/openai_client.rb`**: `chat(...)` → `Result`（success?/content/error_kind/usage/duration_ms）。`Net::HTTP.start`（open 3s / write 5s / read は `timeout`）＋外側の全体デッドライン24秒（`Process.clock_gettime`、Timeout は使わず read_timeout を残り時間で調整）。`OPENAI_API_URL` 上書き。ログはステータス・時間・トークンのみ。呼び出しごとに `AiUsageLog` を1行記録（失敗はrescueしてログのみ）。着手時にOpenAI公式仕様で `max_completion_tokens` / `temperature` 互換性を再確認
3. **`AiUsageLog` モデル**（feature enum相当のバリデーション、user/match_info は optional）
4. **`ChatgptService` 置換**: `OpenaiClient` を使い、失敗時は `nil` を返す。プロンプト生成ロジックは不変。全文ログを削除
5. **`MatchInfo`**: `LEGACY_FAILURE_ADVICE` 定数、`advice_available?`（legacy文言は未生成扱い）。`update_advice` は成功時のみ使用
6. **`app/services/advice_generator.rb`**: analysis_type で分岐、atomic UPDATE による claim（45秒失効）、成功時のみ保存＋`advice_failed_at` クリア、失敗時は `advice_failed_at` 設定、ensure で `advice_generating_at` 解除。戻り値は状態（:generated / :busy / :failed / :existing）
7. **`MatchInfosController`**: `show` を AdviceGenerator 利用に書き換え（有効advice再利用／失敗済みは自動再生成しない）。`post :generate_advice`（member）追加、`set_match_info` スコープ維持。クラス長は既にrubocop disable済み
8. **ビュー**: show.html.erb の両分岐で、失敗・生成中時はエラーカード＋「もう一度生成する」ボタン（`button_to`、`data-controller="loading-button"`）。基本分析は常に表示
9. **`app/javascript/controllers/loading_button_controller.js`**: 送信で disabled＋「生成中…」
10. **routes.rb**: `member { post :generate_advice }`

## テスト
- 新規: `openai_client_spec` / `advice_generator_spec` / `ai_usage_log` 記録 / `spec/requests/match_infos_generate_advice_spec.rb`（他ユーザー404→現行 `set_match_info` は一覧へリダイレクトなので、実挙動に合わせて assert）
- 更新: `chatgpt_service_spec`（`OpenaiClient.chat` をスタブ、プロンプトassertionは維持）、既存 match_infos request spec（`show` が外部APIを叩く箇所）
- `bundle exec rspec && bundle exec rubocop --parallel`

## 検証
1. 上記コマンド緑、`curl localhost:3000` が 200
2. ローカル疑似サーバー（scratchpad 内の WEBrick/Ruby スクリプト、`OPENAI_API_URL` 指定）で 正常 / 5xx / 空応答 / 30秒無応答 を再現 → 画面200・失敗非保存・再試行成功・合計24秒以内。連打・2タブで生成1回のみ。`AiUsageLog` とログに本文なしを確認。共有/本番APIキーは触らない
3. evaluator は使い捨ての新規テストユーザーのみ使用

## コミット／デプロイ
- plans の未追跡4ファイル（本ファイル含む）を実装コミットと一緒にコミット
- PR作成はユーザーの明示指示後。マージ後は `git push heroku main` → `heroku run bin/rails db:migrate` → `db:migrate:status` 全up → `heroku ps:restart web`（PR説明に適用前は500になり得る旨を明記）
- 完了報告で時間予算・同時生成防止の検証結果、IDOR（`edit`）の件、未検証事項を報告
