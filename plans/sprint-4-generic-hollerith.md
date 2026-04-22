# Sprint 4 追加実装: 「前のゲームに戻る」機能

## Context

現在の「前のゲームを取り消す」ボタンは、直前ゲームの Game レコードおよび関連 Score レコードをすべて削除してから前のゲームフォームに戻る実装になっている。ユーザーはスコアを残したまま前のゲームを再編集したいため、削除せずにスコアを復元して戻る挙動に変更する。

---

## 変更対象ファイル

| ファイル | 変更内容 |
|---|---|
| `app/views/match_infos/_form.html.erb` | ボタンテキスト変更・確認ダイアログ削除 |
| `app/controllers/match_infos_controller.rb` | `undo_game` アクション・関連 private メソッドの改修 |

---

## 実装方針

### 1. ビュー変更（`_form.html.erb` 行140-147）

- ボタンテキスト: `"↩ 前のゲームを取り消す"` → `"↩ 前のゲームに戻る"`
- `turbo_confirm` を削除（確認ダイアログ不要）
- ルート・HTTP メソッド（DELETE `undo_game_match_infos_path`）は変更しない

```erb
<% if @draft_id.present? && @saved_games.any? %>
  <div class="center-text mt-3">
    <%= link_to "↩ 前のゲームに戻る",
        undo_game_match_infos_path(draft_id: @draft_id),
        data: { turbo_method: "delete" },
        class: "btn btn-outline-warning" %>
  </div>
<% end %>
```

### 2. コントローラー変更（`match_infos_controller.rb`）

#### `undo_game` アクション（行74-80）を全面改修

**現行:**
```ruby
def undo_game
  @match_info = current_user.match_infos.find_by(id: params[:draft_id])
  return redirect_to new_match_info_path unless @match_info

  delete_last_game(@match_info)
  redirect_after_undo(@match_info)
end
```

**新実装:**
```ruby
def undo_game
  @match_info = current_user.match_infos.find_by(id: params[:draft_id])
  return redirect_to new_match_info_path unless @match_info

  restore_last_game_to_partial_data(@match_info)
  redirect_to new_match_info_path(draft_id: @match_info.id)
end
```

#### 不要になる private メソッドを削除

- `delete_last_game`（行281-284）: 削除
- `redirect_after_undo`（行286-293）: 削除

#### 新規 private メソッドを追加

```ruby
def restore_last_game_to_partial_data(match_info)
  last_game = match_info.games.order(:game_number).last
  return unless last_game

  partial_data = reconstruct_partial_data(last_game)
  last_game.destroy  # Game + Scores が cascade 削除される
  match_info.update!(partial_game_data: partial_data)
end

def reconstruct_partial_data(game)
  game.scores.each_with_object({}) do |score, hash|
    hash[score.batting_style] = {
      'score' => score.score,
      'lost_score' => score.lost_score
    }
  end
end
```

---

## データフロー

```
「前のゲームに戻る」クリック
↓ DELETE /match_infos/undo_game?draft_id=X
↓ undo_game アクション
  ├─ last_game = match_info.games.last（最後のゲーム取得）
  ├─ partial_data = reconstruct_partial_data(last_game)
  │   └─ game.scores → { "serve" => { "score" => 3, "lost_score" => 2 }, ... }
  ├─ last_game.destroy（Game + Scores を cascade 削除）
  └─ match_info.update!(partial_game_data: partial_data)
↓ redirect_to new_match_info_path(draft_id: match_info.id)
↓ setup_draft_form(@match_info)
  └─ @partial_scores = match_info.partial_game_data
     → フォームが前のゲームのスコアで復元表示される
```

### ゲーム1に戻る（saved_games が空になる）ケース

`redirect_after_undo` を廃止したことで、ゲームが0件になっても `match_info` を削除せず `draft_id` を保持したままリダイレクトする。`setup_draft_form` で `@saved_games = []`、`@current_game_number = 1`、`@partial_scores` にスコアが復元され、ゲーム1の入力フォームがスコア付きで表示される。「前のゲームに戻る」ボタンは `@saved_games.any?` が false になるため非表示。

---

## 検証方法

1. `bundle exec rspec && bundle exec rubocop --parallel` が全通過すること
2. ブラウザで以下の操作を確認:
   - ゲーム1を入力→終了→ゲーム2の画面に「↩ 前のゲームに戻る」が表示される
   - ボタンをタップ→確認ダイアログなしで前のゲームに戻る
   - ゲーム1のスコアがフォームに復元されている
   - 復元されたスコアを修正して再度「Nゲーム目終了」を押せる
   - 戻った後のゲーム2に再入力→正常に試合分析まで完了できる
   - ゲーム2を終了→ゲーム3で「前のゲームに戻る」→ゲーム2スコアが復元される
