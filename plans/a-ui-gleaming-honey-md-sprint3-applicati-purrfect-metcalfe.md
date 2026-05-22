# Sprint 3 修正プラン：得点推移表 UI 改善

## Context

Sprint 3 で実装した得点推移表（Showページ）に対して、以下の観点での改善を行う。
- 技術略称の統一・修正（日本語ユーザー向けに分かりやすい略称へ）
- セクション名の変更（「ゲーム別得点推移」→「ゲーム別得点率」）
- 得点推移表の表示位置をページ下部（AIアドバイスの直前）に変更
- 技術略称モーダル一覧の設置（ユーザビリティ向上）
- スクロールヒントアニメーションの追加（横スクロール可能であることを伝える）

---

## 変更ファイル一覧

| ファイル | 変更内容 |
|---------|---------|
| `app/helpers/application_helper.rb` | 技術略称の修正・`abbr_ja` フィールド追加 |
| `app/views/match_infos/_match_info_detail.html.erb` | タイトル変更・AIアドバイスセクション削除 |
| `app/views/match_infos/show.html.erb` | セクション順序変更・AIアドバイスを最後に移動 |
| `app/views/match_infos/_score_progression.html.erb` | 略称モーダルボタン追加・スクロールヒント追加・`abbr_ja` 使用 |
| `app/assets/stylesheets/match_infos.scss` | スクロールヒントアニメーションCSS追加 |

---

## 詳細実装

### 1. application_helper.rb — 技術略称修正

`BATTING_STYLE_ABBR_MAP` を以下の通り修正する：

| key | 変更前 `abbr` | 変更後 `abbr` | `abbr_ja`（追加） |
|-----|-------------|-------------|-----------------|
| `receive` | `'Rec'` | `'R'` | — |
| `fore_push` | `'FP'` | `'FP'`（変更なし） | `'FT'` を追加 |
| `back_push` | `'BP'` | `'BP'`（変更なし） | `'BT'` を追加 |
| `fore_block` | `'FBk'` | `'FB'` | — |
| `back_block` | `'BBk'` | `'BB'` | — |

- `fore_push` / `back_push` のみ `abbr_ja` フィールドを追加（日本語表示時にTを使用）
- ヘルパーメソッド `batting_style_abbr_info` は変更なし
- **スコア推移表側**では `info[:abbr_ja] || info[:abbr]` で表示値を取得する

### 2. _match_info_detail.html.erb — タイトル変更・AIアドバイス移動

- 行42: `ゲーム別得点推移` → `ゲーム別得点率` に変更
- 行93-96の `<div class="advice-section">` ブロックを**削除**（`show.html.erb` に移動）

### 3. show.html.erb — セクション順序の再構成

現在の順序：
```
1. match_info_detail（AIアドバイス込み）
2. 得点推移表
3. 編集/削除ボタン
```

変更後の順序：
```
1. match_info_detail（AIアドバイスなし）
2. 得点推移表（rallies.any? の場合）
3. AIアドバイスセクション
4. 編集/削除ボタン
```

AIアドバイスセクションのHTMLは `_match_info_detail.html.erb` から `show.html.erb` に移動する。
`@advice` インスタンス変数は既存のコントローラーで設定済みのため変更不要。

### 4. _score_progression.html.erb — 略称モーダルボタン＋スクロールヒント

#### 略称一覧ボタン
セクションタイトル横に「略称一覧」ボタン（`btn-sm`）を配置し、Bootstrap Modal を開く。
モーダル内容：
- 略称一覧テーブル（略称 / 技術名 の2列）
- 各行のデータは `BATTING_STYLE_ABBR_MAP` を参照（`abbr_ja || abbr` を略称として表示）
- モーダル説明文：「表中の略称をタップすると技術名が表示されます」

モーダルは `_score_progression.html.erb` の末尾に Bootstrap Modal マークアップとして追加する。
ボタンは `<h2 class="section-title">得点推移表</h2>` の横（`show.html.erb` 内のセクションタイトル横）に配置。

#### スクロールヒントアニメーション
- `.score-progression-scroll-wrapper` の右端にフェードアウトグラデーション（`::after` 疑似要素）を追加
- `@keyframes scroll-hint` で、ページロード時に自動的に少し右にスクロールして戻るアニメーションをJSで実装
  - `DOMContentLoaded` 時に各 `scroll-wrapper` を `scrollLeft = 40` → 0 に戻す（300ms アニメーション）
  - ラリー数が少なくスクロール不要な場合はアニメーションを発火させない（`scrollWidth > clientWidth` の場合のみ）
- CSSのグラデーションは `.score-progression-scroll-wrapper` の `position: relative` + `::after` で右端にフェードを表示

### 5. match_infos.scss — スクロールヒントCSS

```scss
.score-progression-scroll-wrapper {
  position: relative;  // 追加（既存に relative がなければ）
  
  &.scrollable::after {
    content: '';
    position: absolute;
    top: 0;
    right: 0;
    width: 2rem;
    height: 100%;
    background: linear-gradient(to right, transparent, rgba(255,255,255,0.9));
    pointer-events: none;
  }
}
```

`scrollable` クラスはJSで `scrollWidth > clientWidth` の場合に付与する。
スクロールイベントで末端に達したら `scrollable` クラスを外す。

---

## 検証方法

1. `bundle exec rspec` — 全テストパス確認
2. `bundle exec rubocop --parallel` — Lintパス確認
3. ブラウザで `/match_infos/:id` (ralliesデータあり) を開いて以下を確認：
   - セクション順序：ゲーム別得点率 → 技術別得点率ランキング → 得点推移表 → AIアドバイス
   - `ゲーム別得点率` タイトルが表示されている
   - 得点推移表セルに `FT`/`BT`（fore_push/back_push）が表示されている
   - `Rec` → `R`、`FBk` → `FB`、`BBk` → `BB` が反映されている
   - 「略称一覧」ボタンをタップするとモーダルが開き略称一覧が見える
   - スクロール可能な表でヒントアニメーションが動作する
   - AIアドバイスが一番下に表示されている
4. ralliesデータがない試合のShowページで余計なセクションが表示されないことを確認
