# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

T.T.LOG - AIが卓球の試合を分析し、プレー改善のアドバイスを生成する卓球専門の分析ツール。
Ruby on Rails 7.1.2 / Ruby 3.2.2 のフルスタックWebアプリケーション。

本番URL: https://www.ttlog.jp
デプロイ先: Heroku（web + worker dyno）

## 開発コマンド

```bash
# Docker環境（PostgreSQL 16 + Redis 7.2）
docker-compose up

# サーバー起動（Procfile.dev: Rails + JS build + CSS build/watch）
bin/dev

# テスト
bundle exec rspec
bundle exec rspec spec/models/user_spec.rb  # 単体実行

# Lint
bundle exec rubocop --parallel

# CSS/JSビルド
yarn build:css
yarn watch:css
yarn build --watch

# DB操作
rails db:create && rails db:migrate
rails db:schema:load
```

## アーキテクチャ

### コアフロー
1. ユーザーが試合データ（日程/大会名/選手名/技術ごとの得失点）を入力
2. `MatchInfosController#create` で match_info, scores を保存
3. `AdviceGenerationJob`（Sidekiq）が非同期で `ChatgptService` を呼び出し
4. OpenAI GPT-4 が技術統計を分析してアドバイスを生成、`match_info.advice` に保存
5. フロントエンドは Stimulus の `advice_controller.js` でポーリングして結果を表示

### 主要モデル関連
- **User** → has_many **MatchInfo** → has_many **Score** / has_many **Game**
- **MatchInfo** → belongs_to **Player**（自分）, belongs_to **Player**（対戦相手、`opponent`）
- **Score** の `batting_style` はenum（serve, receive, fore_drive, back_drive, fore_push, back_push, fore_stop, back_stop, fore_flick, back_flick, chiquita, fore_block, back_block, fore_counter, back_counter）

### 技術スタック
- **認証**: Sorcery（パスワードリセット、remember-me）
- **検索**: Ransack
- **非同期処理**: ActiveJob + Sidekiq（Redis）
- **フロントエンド**: Stimulus.js + Turbo（importmap-rails）、Bootstrap 5.3.2（cssbundling-rails）
- **ページネーション**: Pagy
- **AI**: OpenAI API（GPT-4、ChatgptService経由）
- **メール**: Gmail SMTP（パスワードリセット用）

## RuboCop設定

- 最大行長: 120文字
- メソッド長: 20行、クラス長: 200行
- 日本語コメント許可
- frozen_string_literal不要
- ダブル/シングルクォートの強制なし
- RSpecブロックは120行まで許可

## 環境変数

`.env` で管理（`.env.development` でローカル上書き）。主要なキー:
- `OPENAI_API_KEY` - OpenAI APIキー（gpt-4o-mini）
- `DATABASE_URL` - 本番DB接続先
- `REDIS_URL` - Sidekiq用Redis
- `RAILS_MASTER_KEY`, `SECRET_KEY_BASE`
- `TWITTER_*` - Twitter連携
- `GMAIL_*` - メール送信

## ルーティング構造

- `/` → `homes#top`（ランディングページ）
- `/match_infos` → CRUD + `/advice_status`（JSON）+ `/autocomplete`
- `/login`, `/logout` → セッション管理
- `/password_resets` → パスワードリセットフロー
- `/sidekiq` → 管理画面（Basic認証付き）

## デザイン

デザインに関する実装をする際は、プロジェクトルートの `DESIGN.md` を参照すること。

## 開発ワークフロー

- **プランなしで実装しない** — ブランチを切って実装する場合は必ず事前にプランを立てること。実装後に修正点が発生した場合も、再度プランを立ててから実装すること。プランなしで実装するとイメージと異なる実装になりやすい。
- **スプリントごとにブランチ・PRを作成する** — プランモードで計画したスプリントごとにブランチを切って実装すること。PRの作成はユーザーが明示的に指示するまで行わない。ただしPRをマージしてから次のスプリントへ進むルールは変わらず、次スプリントへ進む前に必ずPRのマージが完了していること。複数スプリントをまとめてPRにしない。
- **plansファイルは実装コミットと一緒にコミットする** — PR作成時に未コミットのplansファイルが残らないよう、実装コミットと同時にコミットすること。
- プランに基づいた実装の際は、必ず新たなブランチを切ってから作業を開始すること
- 実装後は必ず RSpec テストと RuboCop Lint チェックを両方実行し、すべてパスしていることを確認すること

```bash
bundle exec rspec && bundle exec rubocop --parallel
```

## プルリクエスト

PRを作成する際は `.github/PULL_REQUEST_TEMPLATE.md` のテンプレートを使用すること。

## サブエージェント（Planner / Generator / Evaluator）

このプロジェクトには3つのサブエージェントが定義されている（`.claude/agents/` 配下）。
新機能の開発はこのワークフローに従うこと。

### エージェント役割

| エージェント | 役割 | 使うタイミング |
|-------------|------|--------------|
| **planner** | 短い説明を詳細な仕様書に展開する | 「〜を作りたい」という要望を受けたとき |
| **generator** | 仕様書のスプリントを1つずつ実装する | planner が承認された仕様書を渡すとき |
| **evaluator** | 実装をPlaywright MCPで検証し合否を出す | generator がスプリント完了を報告したとき |

### 標準ワークフロー

```
ユーザーの要望
    ↓
[planner] 仕様書を生成 → plans/{name}.md に保存
    ↓ ユーザー承認
[generator] Sprint 1 を実装 → feature/sprint-1-xxx ブランチ
    ↓ 自己評価チェックリストをパス
[evaluator] 動作検証 → 合格 / 不合格レポート
    ↓ 合格
ユーザーに完了報告 → 次スプリントへ進む指示を待つ
```

不合格の場合は generator に差し戻し、同じバグを3回修正しても解決しない場合はユーザーに相談する。

### 呼び出しルール

- **planner より先に generator を呼ばない** — 仕様書なしで実装を開始しない
- **generator より先に evaluator を呼ばない** — 実装完了報告を受けてから検証する
- **スプリントは1つずつ** — generator は複数スプリントをまとめて実装しない
- **ユーザー承認を挟む** — 各スプリント完了後、次スプリントへ進む前にユーザーの明示的な指示を待つ

### 仕様書の保存場所

- `plans/` ディレクトリに Markdown 形式で保存する
- ファイル名は `{kebab-case-product-name}.md`（例: `user-ranking-feature.md`）
- 仕様書はプロジェクト固有の内容を記載し、技術実装詳細（DBスキーマ等）は含めない

### generator の実装ルール（このプロジェクト固有）

generator がこのプロジェクトでコードを書く際は、以下を必ず守ること:

- ブランチ名: `feature/sprint-{N}-{short-name}`
- テスト: `bundle exec rspec` でパスすること
- Lint: `bundle exec rubocop --parallel` でパスすること
- RuboCop の最大行長は120文字、メソッド長は20行
- デザイン変更を伴う場合は `DESIGN.md` を参照すること

### evaluator の検証ルール（このプロジェクト固有）

- アプリ起動確認: `curl -s -o /dev/null -w "%{http_code}" http://localhost:3000` が 200 を返すこと
- RSpec・RuboCop のパスを合格条件に含める
- 推測で合格にしない — 実際にブラウザ操作で確認した機能のみ合格とする
