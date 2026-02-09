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
- `OPENAI_API_KEY` - GPT-4 APIキー
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
