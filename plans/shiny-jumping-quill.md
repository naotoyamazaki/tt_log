# サーブ・レシーブ分析 バグ修正プラン

## Context

`pr-77-phase-0-77-1-replicated-twilight-m-pure-minsky.md`（Sprint 2〜4、サーブ・レシーブ入力フロー）の動作確認で、以下2件の不具合と1件の改善要望が見つかった。

1. 「前のゲームに戻る」で前のゲーム画面に戻ると得点板が0表示になり、ユーザーが混乱する
2. サーブ・レシーブ分析にも技術別得点率分析と同等の「ブラウザ予期せず終了時の下書き保存」機能があるか要確認
3. 分析一覧ページで技術別得点率分析のデータにもラベルを付けたい（サーブ・レシーブとは別色）

調査の結果、2は既に実装済み・両フロー共通で正しく動作していることを確認済みのため対応不要。1と3のみ修正する。

## 調査結果

### 不具合1: 得点板が0になる原因

- 得点板は `_scoreboard.html.erb` + `scoreboard_controller.js` で、`rally:scoreUpdated` カスタムイベントを受けて表示を更新する。
- 旧機能の `app/javascript/controllers/rally_input_controller.js` の `connect()` （67-73行目）は、初期パターン復元後に以下を実行しており、これが得点板への通知トリガーになっている。
  ```js
  this.updateScore()
  this.updateEndGameButton()
  this.serializeRallies()
  this.updateServerUI()
  if (this.rallies.length > 0) this.dispatchScoreUpdated()
  ```
- 一方、サーブ・レシーブ側の `app/javascript/controllers/serve_receive_input_controller.js` の `connect()` （52-72行目）には、初期パターン復元後に `dispatchScoreUpdated()` を呼ぶ処理が無い。`dispatchScoreUpdated()` 自体は444行目に既に定義されており、他の箇所（280行目・297行目、パターン追加時）では呼ばれている。
- そのため「前のゲームに戻る」→ `restore_last_serve_receive_to_partial_data` で前ゲームのパターンが復元されて画面に表示されても、得点板だけは通知を受け取れず0のままになる。

**修正方針:** `serve_receive_input_controller.js` の `connect()` 内、`this.updateServerUI()` の直後に、旧機能と同じガード付きで通知を追加する。

```js
this.updateServerUI()
if (this.patterns.length > 0) this.dispatchScoreUpdated()
```

### 不具合2: 下書き保存

- `auto_save_controller.js`（localStorageベース、30秒間隔 + `beforeunload`）は `_form.html.erb` と `_serve_receive_form.html.erb` の両方に既に `data-controller` として付与済み。`analysis_type` による復元パス振り分けもサーバー側 `MatchInfosController#restore_autosave` で対応済み。
- **対応不要**（既に共通実装されており正常動作を確認済み）。

### 要望3: 技術別得点率分析のラベル追加

- `app/views/match_infos/_match_info_summary.html.erb` の19-21行目:
  ```erb
  <% if match_info.serve_receive? %>
    <span class="badge bg-info text-dark ms-1">サーブ・レシーブ</span>
  <% end %>
  ```
- `MatchInfo` は `analysis_type` enum（`technique: 0, serve_receive: 1`）を持つため、`match_info.technique?` で技術別データを判定できる。
- 下書きバッジが既に `bg-warning` を使用しているため、色の重複を避けてユーザーが選んだ **`bg-secondary`（グレー）** を技術別分析ラベルに使う。

**修正方針:** 同partialに `elsif match_info.technique?` 分岐を追加。

```erb
<% if match_info.serve_receive? %>
  <span class="badge bg-info text-dark ms-1">サーブ・レシーブ</span>
<% elsif match_info.technique? %>
  <span class="badge bg-secondary ms-1">技術別得点率</span>
<% end %>
```

## 実装対象ファイル

- `app/javascript/controllers/serve_receive_input_controller.js` — `connect()` に得点板通知の追加（1行）
- `app/views/match_infos/_match_info_summary.html.erb` — 技術別ラベルの分岐追加

## ブランチ運用

CLAUDE.mdのルールに従い、既存Sprintの延長ではなくバグ修正のため新規ブランチを切る:
`fix/serve-receive-scoreboard-and-labels`

## 検証方法

1. `bundle exec rspec && bundle exec rubocop --parallel` がパスすること
2. ローカルサーバーを起動し、サーブ・レシーブ分析で2ゲーム以上進めた状態から「前のゲームに戻る」を押し、得点板が前ゲーム終了時点のスコアを表示することをブラウザで確認
3. 分析一覧ページで、技術別得点率分析のカードに灰色の「技術別得点率」バッジが表示され、サーブ・レシーブのカードには従来通り水色の「サーブ・レシーブ」バッジが表示されることを確認
