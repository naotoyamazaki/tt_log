# Herokuデプロイ警告対応プラン

## Context

Herokuへのデプロイ（v105）時に複数の警告が出ている。Ruby EOL、Pumaバージョン、Heroku Stack、スラグサイズ、`config.assets.compile`、`node_modules`の追跡など。これらを1つのブランチで段階的に対応し、本番の安定性とセキュリティを改善する。

## ブランチ名

`fix/heroku-deployment-warnings`

## 対応内容

### 1. `node_modules/.yarn-integrity` をGit追跡から除外

Gitに1ファイルだけ残っている。`git rm --cached` で除外する。

```bash
git rm --cached node_modules/.yarn-integrity
```

### 2. `config.assets.compile` を `false` に変更

- **ファイル:** [production.rb:14](config/environments/production.rb#L14)
- **変更:** `config.assets.compile = true` → `config.assets.compile = false`
- Herokuはデプロイ時に `assets:precompile` を自動実行するため、本番でのオンデマンドコンパイルは不要

### 3. Ruby 3.2.2 → 3.2.10（パッチ更新）

パッチバージョンのみの更新。破壊的変更なし。

- **ファイル:**
  - [Gemfile:3](Gemfile#L3) — `ruby "3.2.2"` → `ruby "3.2.10"`
  - [.ruby-version](.ruby-version) — `ruby-3.2.2` → `ruby-3.2.10`
- **コマンド:** `bundle install` で Gemfile.lock の RUBY VERSION が自動更新される

### 4. Puma 6.4.2 → 7.x（メジャー更新）

Heroku Router 2.0 互換のため Puma 7.0.3+ が推奨。

- **ファイル:**
  - [Gemfile:8](Gemfile#L8) — `gem "puma", ">= 5.0"` → `gem "puma", "~> 7.0"`
  - [config/puma.rb](config/puma.rb) — Puma 7.x の破壊的変更に応じて修正が必要な場合あり
- **コマンド:** `bundle update puma`
- **確認ポイント:** `worker_timeout`（23行目）、`plugin :tmp_restart`（35行目）の互換性

### 5. `.slugignore` 作成（スラグサイズ削減）

スラグサイズ 424MB → 300MB以下を目指す。

- **ファイル:** `.slugignore`（新規作成）
- **内容:**
  ```
  /spec
  /doc
  /plans
  /.rspec
  ```

### 6. Heroku Stack Heroku-22 → Heroku-24

コード変更なし。フェーズ1-5のデプロイ成功確認後にCLIで実行。

```bash
heroku stack:set heroku-24 -a ttlog
git push heroku main
```

## 実施手順

1. `fix/heroku-deployment-warnings` ブランチを作成
2. 上記 1〜5 のコード変更を実施
3. `bundle install` / `bundle update puma` を実行
4. `bundle exec rspec` でテスト通過を確認
5. `bundle exec rubocop --parallel` でLint通過を確認
6. PRを作成（テンプレート使用）
7. マージ後、Herokuにデプロイして警告が減ったことを確認
8. 問題なければ Heroku Stack を Heroku-24 に更新（手順6）

## 検証方法

- `bundle exec rspec` — 全テスト通過
- `bundle exec rubocop --parallel` — Lint通過
- `bin/dev` でローカル起動確認
- Herokuデプロイ後、https://www.ttlog.jp で画面表示・CSS/JS読み込みが正常なことを確認
- デプロイログで警告の減少を確認
