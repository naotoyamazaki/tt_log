# #108 開発環境をDockerに戻す

## Context

現在の開発環境は `bin/dev`（foreman）でローカルのPostgreSQL・Redisを使う構成になっている。
以前はDocker化されていたが、`Dockerfile` が削除され `Dockerfile.bak` としてバックアップされている状態。

**目的**: 開発環境をDockerに戻し、`docker compose up` で一発起動できる状態にする。

**現在の問題点**:
- `Dockerfile` が存在しない（`Dockerfile.bak` のみ）
- `Dockerfile.bak` の内容が本番用（`RAILS_ENV=production`、`assets:precompile`、Ruby 3.2.2）
- `.env.development` の接続先が `localhost` のままで Docker サービス名に対応していない

**注意**:
- #103 で Sidekiq worker による非同期処理は廃止済み（同期処理に変更）のため、worker サービスは不要
- Redis も実質不要だが、`config/initializers/sidekiq.rb` がまだ残っているため redis サービスは維持しておく（Sidekiq gem 削除は別タスク）

---

## 変更ファイル一覧

| ファイル | 操作 |
|---|---|
| `Dockerfile` | 新規作成（`Dockerfile.bak` を開発用に更新）|
| `docker-compose.yml` | 更新（環境変数整理）|
| `docker-compose.override.yml` | 更新（DB/Redis 接続先をサービス名に変更）|
| `.dockerignore` | 確認・必要に応じて更新 |

---

## 実装手順

### 1. `Dockerfile` の作成（開発用）

`Dockerfile.bak` をベースに以下を修正して `Dockerfile` として作成：

```dockerfile
FROM ruby:3.2.10-slim
ENV LANG C.UTF-8
ENV TZ Asia/Tokyo
ENV RAILS_ENV development
ENV BUNDLE_PATH /usr/local/bundle

RUN apt-get update -qq \
  && apt-get install -y curl gnupg build-essential libpq-dev libvips libvips-dev pkg-config postgresql-client \
  && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get install -y nodejs \
  && npm install -g yarn

WORKDIR /tt_log

COPY Gemfile Gemfile.lock package.json yarn.lock ./

RUN gem install bundler \
  && bundle install \
  && yarn install

COPY . .

RUN gem install foreman

EXPOSE 3000

CMD ["bin/dev"]
```

変更点:
- `ruby:3.2.2-slim` → `ruby:3.2.10-slim`（Gemfile のバージョンに合わせる）
- `RAILS_ENV=production` → `development`
- `BUNDLE_DEPLOYMENT=1` 削除（開発では不要）
- Node.js 16 → 20（現行 LTS）
- `assets:precompile` 削除（開発では不要）
- `useradd rails` 削除（開発では root でも問題ない、volume マウントで権限問題を避ける）
- CMD を `bin/dev`（foreman）に変更し、Rails + JS + CSS を一括起動

### 2. `docker-compose.yml` の更新

```yaml
version: '3'
services:
  db:
    image: postgres:16
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    volumes:
      - ./tmp/db:/var/lib/postgresql/data
  redis:
    image: redis:7.2
    ports:
      - "6379:6379"
  web:
    build: .
    command: /bin/sh -c "rm -f tmp/pids/server.pid && bin/dev"
    env_file:
      - ./.env
    environment:
      PGHOST: db
      PGPORT: 5432
      PGUSER: postgres
      PGPASSWORD: password
      REDIS_URL: redis://redis:6379/1
    volumes:
      - .:/tt_log
      - bundle:/usr/local/bundle
    ports:
      - "3000:3000"
    depends_on:
      - db
      - redis
volumes:
  bundle:
```

変更点:
- db サービスの `POSTGRES_USER/PASSWORD` を固定値に変更（`.env` に依存しない）
- web サービスに `environment` セクション追加（Docker サービス名で接続）
- `bundle` named volume 追加（gem キャッシュ・ビルド高速化）

### 3. `docker-compose.override.yml` の確認・整理

現在は `RAILS_ENV=development` のみ設定されている。
`environment` の重複を避けるため、docker-compose.yml 側に移動して override.yml を削除か空にする。

---

## セットアップ手順（README や Wiki 用）

```bash
# 初回セットアップ
docker compose build
docker compose run --rm web rails db:create db:migrate

# 起動
docker compose up

# テスト
docker compose run --rm web bundle exec rspec
```

---

## 検証方法

1. `docker compose build` がエラーなく完了すること
2. `docker compose up` 後、`http://localhost:3000` にアクセスできること
3. ログイン・試合記録の作成が動作すること（DB 接続確認）
4. 試合記録作成後、アドバイスが同期で即時表示されること（#103 の動作確認）
5. `bundle exec rspec` がパスすること
