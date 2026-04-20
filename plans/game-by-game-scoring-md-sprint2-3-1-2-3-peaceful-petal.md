# Sprint 3 実装プラン: 入力体験の向上

## Context

Sprint 1・2でゲーム別得点記録・分析を実装済み。Sprint 3では入力体験を向上させる3機能を実装する。
- **F11**: ゲーム入力の取り消し（Undo）
- **F12**: 途中保存ボタン + 一覧でのドラフト表示（localStorage自動保存は次Sprint）
- **F13**: 試合形式の選択（3/5/5/7ゲームマッチ）

## ブランチ

`feature/sprint-3-input-ux`

---

## F11: ゲーム入力の取り消し（Undo）

直前に保存したゲームを削除し、前のゲーム番号の入力フォームに戻れる機能。

### 変更ファイル

**`config/routes.rb`**
```ruby
collection do
  post :end_game
  delete :undo_game  # 追加
end
```

**`app/controllers/match_infos_controller.rb`**
- `undo_game` アクションを追加
  - `params[:draft_id]` で MatchInfo を取得
  - 最後のゲーム（`games.order(:game_number).last`）とその Scores を削除
  - ゲームが0件になったら MatchInfo ごと削除して `new_match_info_path` へ
  - ゲームが残る場合は `new_match_info_path(draft_id: @match_info.id)` へリダイレクト

**`app/views/match_infos/_form.html.erb`**
- `@draft_id.present? && @saved_games.any?` のときのみ表示するボタンを追加
  ```erb
  <%= button_to "↩ 前のゲームを取り消す",
      undo_game_match_infos_path,
      method: :delete,
      params: { draft_id: @draft_id },
      data: { turbo_confirm: "直前のゲームの入力を取り消しますか？" },
      class: "btn btn-outline-warning" %>
  ```

---

## F12: 途中保存 + ドラフト表示

### DBマイグレーション

`match_infos` テーブルに `draft` boolean カラムを追加：
```ruby
add_column :match_infos, :draft, :boolean, default: false, null: false
```

### 変更ファイル

**`app/controllers/match_infos_controller.rb`**
- `end_game`: MatchInfo 保存後に `match_info.update_columns(draft: true)` を呼ぶ
- `create`: 保存後に `@match_info.update_columns(draft: false)` を呼ぶ（draft → 完了に変更）
- `index`: ランサックのクエリは変えない（ドラフトも一覧に表示）

**`app/views/match_infos/_form.html.erb`**
- `@draft_id.present?` のときのみ「途中で中断する」リンクを表示
  ```erb
  <%= link_to "途中で中断する", match_infos_path, class: "btn btn-outline-secondary" %>
  ```

**`app/views/match_infos/_match_info_summary.html.erb`**
- `match_info.draft?` のとき「下書き」バッジを表示
- 「試合分析詳細」ボタンを「続きから入力」リンク（`new_match_info_path(draft_id: match_info.id)`）に差し替え
- 通常の完了済み試合は変更なし

---

## F13: 試合形式の選択

`match_format` カラムは既存（`default: 5`）。UIと連携のみ実装。

### 変更ファイル

**`app/views/match_infos/_form.html.erb`**
- `@draft_id.nil?`（1ゲーム目のみ）のときに試合形式セレクターを表示
  ```erb
  <% if @draft_id.nil? %>
    <%= f.select :match_format, [[3, 3], [5, 5], [7, 7]],
        { selected: 5 },
        class: "form-select",
        data: { action: "change->scoreboard#changeFormat" } %>
  <% end %>
  ```

**`app/controllers/match_infos_controller.rb`**
- `basic_match_info_params` に `:match_format` を追加

**`app/views/match_infos/_scoreboard.html.erb`**
- `max_games` を 7 固定でレンダリングし、各スロットに `data-max-format` 属性を付与
  ```erb
  <div class="game-score-placeholder"
       data-game-idx="<%= i %>"
       data-scoreboard-target="gameSlot"
       class="<%= i >= max_games ? 'd-none' : '' %>">ー</div>
  ```

**`app/javascript/controllers/scoreboard_controller.js`**
- `static targets` に `gameSlot` を追加
- `changeFormat(event)` アクションを追加
  ```javascript
  changeFormat(event) {
    const format = parseInt(event.target.value)
    this.gameSlotTargets.forEach((slot, i) => {
      slot.classList.toggle('d-none', i >= format)
    })
  }
  ```

---

## 変更ファイル一覧

| ファイル | 変更内容 |
|---------|---------|
| `config/routes.rb` | `undo_game` ルート追加 |
| `db/migrate/YYYYMMDD_add_draft_to_match_infos.rb` | `draft` カラム追加 |
| `app/controllers/match_infos_controller.rb` | `undo_game` 追加、`draft` フラグ設定、`match_format` パラメータ追加 |
| `app/views/match_infos/_form.html.erb` | Undo ボタン・中断リンク・形式セレクター追加 |
| `app/views/match_infos/_match_info_summary.html.erb` | 下書きバッジ・「続きから」ボタン追加 |
| `app/views/match_infos/_scoreboard.html.erb` | 7スロット固定 + `gameSlot` ターゲット追加 |
| `app/javascript/controllers/scoreboard_controller.js` | `changeFormat` アクション追加 |
| `spec/` | 各機能のテスト追加 |

---

## 確認方法

1. `bundle exec rails db:migrate` を実行
2. `bundle exec rspec && bundle exec rubocop --parallel` がパスすること
3. 試合形式で「3ゲーム」を選択するとスコアボードのスロットが3つになること
4. 2ゲーム目以降のフォームで「↩ 前のゲームを取り消す」を押すと直前のゲームが削除され1つ前に戻ること
5. 「途中で中断する」を押すと試合一覧に戻り、該当試合に「下書き」バッジが表示されること
6. 「続きから入力」を押すと中断した続きから入力できること
