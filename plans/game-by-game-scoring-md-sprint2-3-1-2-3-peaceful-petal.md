# Sprint 2 修正プラン（追加）: スタイル調整

## Context

Sprint 2 実装後の細かいUI調整。3点の修正が必要：
1. 一覧画面のゲーム数バッジが小さく・暗色で見づらい
2. 詳細画面のゲーム数バッジももう少し大きくしたい
3. 分析フォームのスコアボードがスマホ表示で得点数が2行になり、2桁の数値がカード外にはみ出す

## 変更内容

### 1. 一覧画面: `.game-count-chip` のサイズ・カラー変更

**ファイル:** `app/assets/stylesheets/match_infos.scss`

| プロパティ | 変更前 | 変更後 |
|-----------|--------|--------|
| `font-size` | `0.85rem` | `1rem` |
| `color` | `#0D47A1`（濃紺） | `rgba(255,255,255,0.9)`（ホワイト系） |
| `background-color` | `rgba(100,181,246,0.3)` | `rgba(255,255,255,0.15)`（半透明ホワイト、カードの暗背景に合わせる） |

### 2. 詳細ページ: `.game-count-badge` のサイズ変更（カラーはそのまま）

**ファイル:** `app/assets/stylesheets/match_infos.scss`

| プロパティ | 変更前 | 変更後 |
|-----------|--------|--------|
| `font-size` | `0.85rem` | `1rem` |

### 3. スコアボード: スマホ表示時のサイズ調整

**ファイル:** `app/assets/stylesheets/match_infos.scss`

`@media (max-width: 768px)` ブロック内に以下を追加：

```scss
// 得点数（左右）を縮小して1行に収める
.scoreboard-score {
  font-size: 2.2rem;
}

// ゲーム数（左右の勝利数）を縮小
.game-wins-left,
.game-wins-right {
  font-size: 2.4rem;
}

// 中央エリアの最小幅をリセット
.scoreboard-center {
  min-width: 0;
}

// コンテナのギャップを狭める
.game-scores-container {
  gap: 0.5rem;
}
```

## 変更ファイル

| ファイル | 変更内容 |
|---------|---------|
| `app/assets/stylesheets/match_infos.scss` | `.game-count-chip` サイズ・カラー変更、`.game-count-badge` サイズ変更、スコアボードのスマホ用メディアクエリ追加 |

## 確認方法

1. `bundle exec rubocop --parallel` でパスすること（SCSSは対象外だがRubyファイル無変更）
2. 一覧画面のゲーム数バッジが白系カラーで少し大きく表示されること
3. 詳細画面の「ゲーム別スコア」見出し横のバッジが少し大きく表示されること
4. ブラウザの開発者ツールでスマホ幅（375px相当）にしたとき、スコアボードの得点数が1行・カード内に収まること（2桁でも）
