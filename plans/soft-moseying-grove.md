# #78 不要なファイル・コード削除

## Context

コードベースの見通しを良くし、以降の機能追加（#97, #77）をスムーズに進めるための整理。
過去の機能廃止（Twitter連携の未実装放棄、BattingStyleテーブル削除、非同期処理→同期処理移行 #103）
により残存した不要コードを削除する。

---

## 削除対象一覧

### Phase 1: ファイルごと削除（リスク低）

| # | ファイル | 理由 |
|---|---------|------|
| 1 | `app/models/batting_style.rb` | テーブルはmigrationで削除済み。空のモデルが残存 |
| 2 | `test/models/batting_style_test.rb` | 上記モデル対応の空テスト |
| 3 | `app/models/concerns/twitter_client.rb` | Twitter連携は未実装。どのモデルにもincludeされていない |
| 4 | `app/javascript/controllers/hello_controller.js` | Railsデフォルトのサンプルコード。ビューから参照なし |
| 5 | `app/javascript/controllers/input_controller.js` | ビューから参照なし（`data-controller="input"` の使用箇所ゼロ） |
| 6 | `app/helpers/match_infos_helper.rb` | 空ファイル |
| 7 | `app/helpers/user_sessions_helper.rb` | 空ファイル |
| 8 | `app/helpers/users_helper.rb` | 空ファイル |
| 9 | `app/helpers/password_resets_helper.rb` | 空ファイル |
| 10 | `config/credentials.yml.enc.bak` | 認証情報のバックアップファイル。不要 |

### Phase 2: コード修正（リスク低〜中）

| # | ファイル | 変更内容 |
|---|---------|---------|
| 11 | `app/models/match_info.rb:9` | `attr_accessor :post_to_x` 削除（Twitter機能廃止） |
| 12 | `app/controllers/match_infos_controller.rb` | `permit`内の `:post_to_x` 削除 |
| 13 | `app/helpers/application_helper.rb:14-22` | `prepare_batting_score_data` メソッド削除（MatchInfoモデル側に同等実装あり、ビューから未使用） |
| 14 | `app/models/score.rb:20-29` | コメントアウトされたバリデーションコード削除 |

### Phase 3: Gemfile / package.json 整理

| # | 対象 | 変更内容 |
|---|-----|---------|
| 15 | `Gemfile` | `gem 'twitter'` 削除（TwitterClient削除に伴い不要） |
| 16 | `Gemfile` | `bundle install` で lockfile更新 |

---

## 対象外（慎重に除外した項目）

| 項目 | 除外理由 |
|-----|---------|
| `gem 'sidekiq'` / `config/initializers/sidekiq.rb` | Issue #103の対応方針として「削除しない」とされている |
| `gem 'sitemap_generator'` | `config/sitemap.rb` が存在し使用されている |
| `Game` モデル / `games` テーブル | 削除にはマイグレーション作成が必要。Score.game_idとの整合確認も必要で別Issueとして扱う |
| `stimulus-autocomplete` (package.json) | autocompleteコントローラーが実際にビューで使用されており確認が必要 |

---

## 実装手順

```
1. 新ブランチ作成: git checkout -b feature/remove-unnecessary-files-issue-78

2. Phase 1: ファイル削除（10ファイル）
   - 各ファイルを削除

3. Phase 2: コード修正（4箇所）
   - match_info.rb の attr_accessor :post_to_x 削除
   - match_infos_controller.rb の :post_to_x 削除
   - application_helper.rb の prepare_batting_score_data 削除
   - score.rb のコメントアウトコード削除

4. Phase 3: Gemfile修正
   - gem 'twitter' 削除
   - bundle install

5. 動作確認・テスト実行
```

---

## 修正対象ファイル

- [app/models/batting_style.rb](app/models/batting_style.rb)
- [test/models/batting_style_test.rb](test/models/batting_style_test.rb)
- [app/models/concerns/twitter_client.rb](app/models/concerns/twitter_client.rb)
- [app/javascript/controllers/hello_controller.js](app/javascript/controllers/hello_controller.js)
- [app/javascript/controllers/input_controller.js](app/javascript/controllers/input_controller.js)
- [app/helpers/match_infos_helper.rb](app/helpers/match_infos_helper.rb)
- [app/helpers/user_sessions_helper.rb](app/helpers/user_sessions_helper.rb)
- [app/helpers/users_helper.rb](app/helpers/users_helper.rb)
- [app/helpers/password_resets_helper.rb](app/helpers/password_resets_helper.rb)
- [config/credentials.yml.enc.bak](config/credentials.yml.enc.bak)
- [app/models/match_info.rb](app/models/match_info.rb) （コード修正）
- [app/controllers/match_infos_controller.rb](app/controllers/match_infos_controller.rb) （コード修正）
- [app/helpers/application_helper.rb](app/helpers/application_helper.rb) （コード修正）
- [app/models/score.rb](app/models/score.rb) （コメントアウト削除）
- [Gemfile](Gemfile) （gem 'twitter' 削除）

---

## 検証方法

```bash
# テスト全通過確認
bundle exec rspec

# Lint確認
bundle exec rubocop --parallel

# 開発サーバー起動して動作確認
bin/dev
# → ログイン、試合登録、分析表示が正常に動作するか確認
```
