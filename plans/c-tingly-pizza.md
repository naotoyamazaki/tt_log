# UI/UX デザインモダン化計画 — 案C: ライトモード × モダンスポーツ

## Context

現在の T.T.LOG は Bootstrap 5 のデフォルトスタイルにグリーン→シアンのグラデーションを重ねた第一世代デザイン。
ESPN / Sports Reference を参考に、**白ベースのまま**カード・タイポグラフィ・カラーをシャープにモダン化する。
ダークモードへの移行は不要なため実装コストが低く、現在のユーザーが感じる「親しみやすさ」を残しつつ
データ可視化ツールとしての信頼感・見やすさを向上させる。

---

## デザイン方針

| 項目 | 現状 | 目標 |
|------|------|------|
| 背景 | ライト（Bootstrap default） | 白 `#ffffff` + ライトグレー `#f8fafc` |
| メインカラー | `#4CAF50` グリーン | `#16a34a`（クリーンなスポーツグリーン） |
| アクセント | `#00B0FF` シアン | `#0ea5e9`（スカイブルー、データ強調） |
| ナビバー | グリーン→シアン グラデーション | 白背景 + ボトムボーダー + グリーンアクセント |
| ボタン | グラデーション + scale | ソリッドカラー + シャープ hover |
| カード | グラデーション背景 | 白 + 細ボーダー + 左アクセントライン |
| フォント | Bootstrap 標準 | Inter Variable（Google Fonts） |
| テキスト | Bootstrap default | `#0f172a`（主）/ `#64748b`（副）/ `#94a3b8`（ミュート） |
| ボーダー | なし〜濃色 | `#e2e8f0`（薄グレー、細線） |

---

## カラートークン（CSS変数）

```scss
// application.bootstrap.scss のトップに定義
:root {
  // ブランドカラー
  --tt-primary:        #16a34a;   // スポーツグリーン
  --tt-primary-dark:   #15803d;   // hover用
  --tt-primary-light:  #dcfce7;   // バッジ・背景薄色用
  --tt-accent:         #0ea5e9;   // スカイブルー（データ強調）
  --tt-accent-light:   #e0f2fe;

  // 背景
  --tt-bg:             #ffffff;
  --tt-bg-muted:       #f8fafc;   // テーブル縞・セクション背景
  --tt-bg-subtle:      #f1f5f9;   // カード内サブエリア

  // テキスト
  --tt-text:           #0f172a;
  --tt-text-sub:       #64748b;
  --tt-text-muted:     #94a3b8;

  // ボーダー・シャドウ
  --tt-border:         #e2e8f0;
  --tt-shadow-sm:      0 1px 3px rgba(0,0,0,.08), 0 1px 2px rgba(0,0,0,.05);
  --tt-shadow:         0 4px 6px rgba(0,0,0,.07), 0 2px 4px rgba(0,0,0,.05);
  --tt-radius:         8px;
}
```

### Bootstrap 変数上書き（`@import 'bootstrap/scss/bootstrap'` の前）

```scss
$primary:       #16a34a;
$secondary:     #64748b;
$success:       #16a34a;
$info:          #0ea5e9;
$body-bg:       #ffffff;
$body-color:    #0f172a;
$font-family-sans-serif: 'Inter Variable', 'Inter', system-ui, sans-serif;
$border-radius: 8px;
$card-border-color: #e2e8f0;
$card-box-shadow: 0 1px 3px rgba(0,0,0,.08);
```

---

## フォント

Inter Variable を Google Fonts から読み込む。

```html
<!-- application.html.erb <head> 内に追加 -->
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:ital,opsz,wght@0,14..32,100..900;1,14..32,100..900&display=swap" rel="stylesheet">
```

---

## スプリント計画

### Sprint 1 — デザインシステム基盤

**目標**: CSS変数・Bootstrap変数上書き・Interフォント読み込みを整備する。

**対象ファイル**:
- `app/assets/stylesheets/application.bootstrap.scss` — Bootstrap変数上書き・CSS変数定義・既存グラデーション廃止
- `app/views/layouts/application.html.erb` — Interフォント `<link>` 追加

**変更内容**:
1. `application.bootstrap.scss` 冒頭に Bootstrap 変数上書きを追加（`@import` より前）
2. `:root` に CSS変数トークン定義を追加
3. 既存の `.navbar` グラデーション・`.btn-primary` グラデーション・`.footer-bottom` ネイビーを一時的にCSS変数ベースに置き換え
4. `application.html.erb` に Interフォント `<link>` を追加

**完了条件**: `bin/dev` でサーバー起動し、フォントが Inter に変わっていること。Bootstrap の `$primary` がグリーン系になっていること。

---

### Sprint 2 — 共通UI（Navbar・Footer・Flash・ボタン）

**目標**: ヘッダー・フッター・フラッシュ・共通ボタンをモダンスポーツスタイルに刷新する。

**対象ファイル**:
- `app/assets/stylesheets/application.bootstrap.scss`
- `app/views/shared/_header.html.erb`
- `app/views/shared/_before_login_header.html.erb`
- `app/views/shared/_footer.html.erb`
- `app/views/shared/_flash_message.html.erb`

**変更内容**:

#### Navbar
- 背景: 白 (`#ffffff`) + ボトムボーダー `1px solid var(--tt-border)`
- ロゴ左寄せ、ナビリンク右寄せ（現状維持）
- `navbar-dark` → `navbar-light` に変更
- ドロップダウン: 白背景 + `var(--tt-border)` ボーダー + シャドウ、hover は `var(--tt-primary-light)`
- ログアウトボタン: `text-danger` → アウトラインスタイル（小サイズ、`border-radius: 6px`）
- 会員登録ボタン: `var(--tt-primary)` 塗り
- ログインボタン: `var(--tt-primary)` アウトライン

#### Footer
- 背景: `var(--tt-bg-muted)` + トップボーダー
- テキスト: `var(--tt-text-sub)`
- リンク hover: `var(--tt-primary)`
- メールアドレス: `var(--tt-accent)` カラー

#### Flash メッセージ
- notice: 左ボーダー `4px solid var(--tt-primary)` + 薄グリーン背景 `var(--tt-primary-light)`
- alert: 左ボーダー `4px solid #ef4444` + 薄レッド背景 `#fee2e2`
- `border-radius: var(--tt-radius)`

#### ボタン共通
- `.btn-primary`: ソリッドグリーン、`border: none`、`border-radius: 6px`、hover で `var(--tt-primary-dark)`
- `.btn-register`: グリーン塗り（`var(--tt-primary)`）
- `.btn-login`: グリーンアウトライン

**完了条件**: ナビバーが白ベースになり、Footer・Flash・ボタンのデザインが刷新されていること。

---

### Sprint 3 — ランディングページ + 認証ページ

**目標**: `homes/top`・ユーザー登録・ログインページをモダンスポーツスタイルに更新する。

**対象ファイル**:
- `app/assets/stylesheets/homes.scss`
- `app/assets/stylesheets/users.scss`
- `app/assets/stylesheets/user_sessions.scss`
- `app/views/homes/top.html.erb`

**変更内容**:

#### ランディングページ
- ヒーローセクション: 白背景 + 左寄せの大きな見出し + グリーンのアクセントライン（`border-left: 4px solid var(--tt-primary)`）
- 「こんな悩みはありませんか？」チャットバブル: `var(--tt-primary-light)` 背景
- 機能紹介カード: 白 + `var(--tt-border)` ボーダー + `var(--tt-shadow-sm)` + アイコン上にグリーンアクセント
- CTAセクション: `var(--tt-primary)` 単色（グラデーション廃止）
- `.section-header` ボーダー: `var(--tt-primary)` に変更（白から変更）

#### 認証ページ
- 背景: グリーン単色 → `var(--tt-bg-muted)` ライトグレー
- フォームカード: 白 + `var(--tt-shadow)` + `var(--tt-radius)`
- フォームフォーカス: `var(--tt-primary)` のボーダー
- ボタン: `var(--tt-primary)` ソリッド

**完了条件**: ランディングページがクリーンな白ベースになり、認証ページが ESPN 風の明るい業務ライクなデザインになっていること。

---

### Sprint 4 — 試合一覧 + 詳細ページ

**目標**: `match_infos#index` と `#show` をデータビジュアライゼーション重視のモダンスポーツスタイルに刷新する。

**対象ファイル**:
- `app/assets/stylesheets/match_infos.scss`（index・show 関連部分）
- `app/views/match_infos/index.html.erb`
- `app/views/match_infos/show.html.erb`（+ `_match_info_detail` パーシャルがあれば）

**変更内容**:

#### 試合一覧カード
- カード背景: 白 + `var(--tt-border)` ボーダー + hover で `var(--tt-shadow)`
- グラデーション背景廃止
- 勝利バッジ: `var(--tt-primary-light)` + `var(--tt-primary)` テキスト
- 敗北バッジ: `#fee2e2` + `#ef4444` テキスト
- ページネーション: Bootstrap デフォルト + `$primary` グリーン

#### 検索フォーム
- `var(--tt-bg-muted)` 背景 + `var(--tt-border)` ボーダー + `var(--tt-radius)`
- `form-container` width 調整（現状 35% → max-width: 640px + mx-auto）

#### 試合詳細
- `show-container` のボーダー・シャドウを CSS変数ベースに
- テーブル hover: 薄グリーン `var(--tt-primary-light)`（現状の薄緑を統一）
- `.edit-btn`・`.delete-btn`: アウトラインボタン風に統一

**完了条件**: 試合一覧・詳細ページがクリーンなカードレイアウトで表示され、スコアの可読性が向上していること。

---

### Sprint 5 — 試合フォーム + スコアボード + クリーンアップ

**目標**: 入力フォーム・スコアボードを整備し、全体の inline style や残存グラデーションを除去する。

**対象ファイル**:
- `app/assets/stylesheets/match_infos.scss`（form・scoreboard 関連部分）
- `app/views/match_infos/new.html.erb`・`edit.html.erb`（inline style 除去）
- 全 scss ファイルの残存ハードコードカラーを CSS変数に置換

**変更内容**:

#### 試合フォーム
- `.form-container` の `box-shadow` → `var(--tt-shadow)`、`border-radius` → `var(--tt-radius)`
- フォーム幅: `width: 35%` → `max-width: 640px; margin: 0 auto`（レスポンシブ対応）
- フォーカス色: `var(--tt-primary)`

#### スコアボード
- `.scoreboard-container` グラデーション廃止 → `var(--tt-primary)` ソリッド + 白テキスト
- `.game-score-result`: 勝利 `var(--tt-primary)` / 敗北 `#ef4444`（CSS変数化）

#### クリーンアップ
- 全 scss ファイルの `#4CAF50`・`#00B0FF`・`#1A237E`・`#1B5E20` をすべて CSS変数に置換
- 重複している `.footer-bottom` セレクタを1つに統合
- `.text-neon` → `var(--tt-accent)` で定義

**完了条件**: RuboCop・RSpec が全パスし、ハードコードされた旧カラーコードが全ファイルから除去されていること。

---

## 検証方法

```bash
# 1. サーバー起動確認
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000
# → 200 を返すこと

# 2. 各スプリント後に実行
bundle exec rspec && bundle exec rubocop --parallel

# 3. ブラウザ確認（Playwright または手動）
# - / (ランディングページ)
# - /login
# - /users/new
# - /match_infos (一覧)
# - /match_infos/:id (詳細)
# - /match_infos/new (フォーム)
```

## ブランチ命名規則

```
feature/sprint-{N}-light-mode-modern-ui
```
