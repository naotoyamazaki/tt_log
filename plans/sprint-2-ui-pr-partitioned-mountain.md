# Sprint 2 追加: サーブ権トラッキング

## Context

Sprint 2（ラリー入力UI）は実装・評価済み（feature/sprint-2-rally-input-ui ブランチ）。
PR 作成前に「誰がサーブ権を持っているか」のデータ収集を追加する。

現在はラリーに `batting_style: serve / receive` は記録できるが、
「そのラリーでサーバーがどちらか」が未記録。このデータがないと
サーブゲーム得点率・3球目攻撃成功率などの分析が将来的に不可能になる。

**今回の目的**: データ収集のみ。分析機能への活用は Sprint 4（AI分析強化）以降。

---

## 実装方針

### サーブ権の導出ルール（卓球の規則）

```
通常時（合計得点 < 20）: Math.floor(total / 2) % 2 === 0 → first_server が現在のサーバー
デュース時（合計得点 >= 20）: total % 2 === 0 → first_server が現在のサーバー
ゲーム間: 前ゲームの first_server の反対がデフォルト（変更可能）
```

各 Rally レコードには `server` を保存しない。
`games.first_server` と `sequence_number` から常に導出できるため。

---

## 変更ファイル一覧

### 1. `db/migrate/XXXXXX_add_first_server_to_games.rb`（新規）

```ruby
add_column :games, :first_server, :integer
```

nullable（既存データは nil のまま）。

### 2. `app/models/game.rb`

```ruby
enum :first_server, { player: 0, opponent: 1 }
```

### 3. `app/views/match_infos/_rally_input.html.erb`

- 「ラリー入力エリア」の前に「サーブ選択エリア」を追加
- `data-rally-input-target="serverSelect"` ブロック（ゲーム開始前のみ表示）
- 「自分がサーブ」「相手がサーブ」ボタン
- 選択後は非表示、現在サーバーインジケーターに切り替わる（「🏓 自分のサーブ中」）
- hidden field: `<input type="hidden" name="first_server" data-rally-input-target="firstServerField">`

```
[サーブ選択エリア（未選択時のみ表示）]
誰がサーブ？
[  自分がサーブ  ]   [  相手がサーブ  ]

[ラリー入力エリア（サーブ選択後に表示）]
🏓 自分のサーブ中  現在のスコア: 自分 0 - 相手 0

ステップ1: 誰が得点した？
[  自分の得点  ]   [  相手の得点  ]
```

### 4. `app/javascript/controllers/rally_input_controller.js`

追加する状態:
- `this.firstServer` — 'player' | 'opponent' | null（未選択）

追加するメソッド:
- `selectServer(event)` — サーバー選択ボタンのハンドラ。serverSelect を非表示、step1 を表示
- `getCurrentServer()` — rallies の長さから現在のサーブ権を計算して返す
- `getServerLabel()` — '自分のサーブ中' / '相手のサーブ中' を返す（UI表示用）

変更するメソッド:
- `connect()` — initialFirstServer value があれば this.firstServer を設定、サーブ選択 UI の表示/非表示を制御
- `updateScore()` — サーバーインジケーターのテキストも更新
- `serializeRallies()` — firstServerField に this.firstServer をセット
- `endGame()` — firstServer が未選択のままゲーム終了を押せないようガード

ゲーム間の引き継ぎ:
- ゲーム終了後、次ゲーム開始時のデフォルトサーバーを前ゲームの反対に自動設定
- `data-rally-input-value-initial-first-server` に前ゲームの opposite を渡す（フォーム側で制御）

### 5. `app/controllers/match_infos_controller.rb`

`create_game_from_rallies` を更新:

```ruby
def create_game_from_rallies(match_info)
  rallies_data = JSON.parse(params[:rallies])
  first_server = params[:first_server].presence  # 'player' or 'opponent' or nil
  game_number = match_info.games.count + 1
  player_total = rallies_data.count { |r| r['winner'] == 'player' }
  opponent_total = rallies_data.count { |r| r['winner'] == 'opponent' }
  game = match_info.games.create!(
    game_number: game_number,
    player_score: player_total,
    opponent_score: opponent_total,
    first_server: first_server
  )
  # 以降は既存処理
end
```

`restore_last_game_to_partial_data` を更新:
- `partial_game_data` に `'first_server'` も保存（undo 時に復元できるように）

### 6. `plans/a-ui-gleaming-honey.md`

Sprint 2 セクションに以下を追記:

```markdown
**サーブ権トラッキング（Sprint 2 追加）:**
- ゲーム開始前に「誰がサーブ？」ボタンを1回選択
- ゲーム内のサーブ権は自動追跡（2本交代、デュース後1本交代）
- ゲーム間は前ゲームの反対側が自動的にデフォルトになる
- `games.first_server` カラム（nullable）に保存
- データ収集のみ。分析活用は Sprint 4 以降
```

### 7. `spec/models/game_spec.rb`

`first_server` enum のテストを追加。

---

## 検証方法

1. `bundle exec rspec && bundle exec rubocop --parallel` 両方パス
2. Playwright で:
   - `/match_infos/new` → サーブ選択UIが表示される
   - 「自分がサーブ」を選択 → ラリー入力エリアが表示、「🏓 自分のサーブ中」表示
   - 2本ごとにサーバーインジケーターが切り替わる
   - 10-10 になったら1本交代に切り替わる
   - 1ゲーム終了 → 2ゲーム目開始時に相手サーブがデフォルトになっている
   - サーブ未選択のままゲーム終了ボタンが押せないこと（ガード確認）
   - undo_game でサーブ権情報も復元されること

---

## 作業ブランチ

既存ブランチ `feature/sprint-2-rally-input-ui` で作業継続。
