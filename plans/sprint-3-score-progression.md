# Sprint 3: 得点推移表（Showページ）

## 概要

MatchInfo の show ページに「得点推移表」セクションを追加する。
Rally レコードを持つゲームのみを対象に、ゲームごとの得点推移を表形式で表示する。

## スコープ

### 対象ファイル

- `app/views/match_infos/show.html.erb` — 得点推移表セクションを追加
- `app/views/match_infos/_score_progression.html.erb` — 新規パーシャル
- `app/assets/stylesheets/match_infos.scss` — 推移表スタイル追加

### 表示仕様

- Rallyレコードがあるゲームのみ表示（後方互換性維持）
- ゲームごとに横方向に得点推移を表形式で表示
- player行（青系）、opponent行（赤系）の2行構成
- 得点ポイントのセルに技術略称を表示（ツールチップで正式名称）
- 横スクロール対応（スマホ考慮）

### 技術略称マッピング

| batting_style            | 略称 | 正式名称 |
|--------------------------|------|----------|
| serve                    | S    | サーブ |
| receive                  | Rec  | レシーブ |
| fore_drive_vs_topspin    | FD+  | フォアドライブ(対上) |
| back_drive_vs_topspin    | BD+  | バックドライブ(対上) |
| fore_drive_vs_backspin   | FD-  | フォアドライブ(対下) |
| back_drive_vs_backspin   | BD-  | バックドライブ(対下) |
| fore_push                | FP   | フォアツッツキ |
| back_push                | BP   | バックツッツキ |
| fore_stop                | FS   | フォアストップ |
| back_stop                | BS   | バックストップ |
| fore_flick               | FF   | フォアフリック |
| back_flick               | BF   | バックフリック |
| chiquita                 | C    | チキータ |
| fore_block               | FBk  | フォアブロック |
| back_block               | BBk  | バックブロック |
| fore_counter             | FC   | フォアカウンター |
| back_counter             | BC   | バックカウンター |
| fore_smash               | FSm  | フォアスマッシュ |
| back_smash               | BSm  | バックスマッシュ |
| net_or_edge              | N/E  | ネット/エッジ |

## 完了条件

- `bundle exec rspec` がパスすること
- `bundle exec rubocop --parallel` がパスすること
- show.html.erb に推移表セクションが追加されていること
- Rallyデータがある場合のみ推移表が表示される条件分岐があること
