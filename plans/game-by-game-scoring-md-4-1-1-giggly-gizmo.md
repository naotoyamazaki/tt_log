# Sprint 4: 途中中断・自動下書き保存・得点板移動

## Context

ゲーム別スコアリング機能（Sprint 1〜3）の入力体験をさらに向上させるスプリント。現状の課題：
- 「途中で中断する」ボタンが2ゲーム目以降にしか表示されず、1ゲーム目から中断できない
- 中断時に入力中の技術別スコア（得点/失点数）が保存されないため、再開時に0からやり直しになる
- 誤ってブラウザを閉じると入力データが全消え
- 編集ページで得点板の位置がUIとして不自然

## 実装対象 Features

### F14: 1ゲーム目からの途中中断

**現状**: 「途中で中断する」は `@draft_id.present?` 条件下でのみ表示（2ゲーム目以降）。

**変更内容**:
- `_form.html.erb` で「途中で中断する」を常時表示（条件削除）
- リンクタグをフォーム POST ボタンに変更（`interrupt_match_infos_path` へ）
- 新アクション `interrupt` を追加（詳細は後述）

### F15: 途中中断時の技術スコア保存と復元

**変更内容**:

**DB Migration**: `match_infos` テーブルに `partial_game_data` JSON カラムを追加
```ruby
add_column :match_infos, :partial_game_data, :jsonb
```

**`interrupt` アクション**（新規）:
```ruby
def interrupt
  find_or_create_players
  @match_info = draft_or_new_match_info(@player, @opponent)
  @match_info.assign_attributes(match_info_params)
  @match_info.draft = true
  @match_info.partial_game_data = game_score_params.to_h  # 入力中のゲームのスコアを保存
  @match_info.save!
  redirect_to match_infos_path, notice: "分析を中断しました。下書きに保存されています。"
end
```

**`end_game` アクション修正**: `create_game_with_scores` 後に `partial_game_data` をクリア
```ruby
@match_info.update!(partial_game_data: nil)
```

**`setup_draft_form` 修正**: `partial_game_data` を `@partial_scores` としてビューに渡す
```ruby
@partial_scores = draft.partial_game_data || {}
```

**`_form.html.erb` 修正**: 各スコア入力フィールドの `value` を `@partial_scores` から復元
```erb
value="<%= @partial_scores.dig(batting_style.to_s, 'score') || 0 %>"
value="<%= @partial_scores.dig(batting_style.to_s, 'lost_score') || 0 %>"
```

適用範囲: 1ゲーム目〜7ゲーム目すべて（フォームは共通テンプレートのため自動適用）

**「途中で中断する」ボタン変更**（`_form.html.erb`）:
- リンクタグ → フォーム POST ボタン（`interrupt_match_infos_path` へ）
- フォームに hidden フィールドとして match_info メタデータ + draft_id + game_scores を含める

### F16: 自動下書き保存（ブラウザを誤って閉じた場合）

**方針**: localStorage + Stimulus コントローラーで実装。  
定期保存（30秒間隔） + `beforeunload` イベントでブラウザ閉じ直前にも保存。

**新規 Stimulus コントローラー**: `auto_save_controller.js`

localStorage キー: `tt_log_autosave`  
保存データ構造:
```json
{
  "draft_id": 123,
  "match_date": "2026-04-20",
  "match_name": "大会名",
  "player_name": "選手名",
  "opponent_name": "相手名",
  "memo": "メモ",
  "match_format": 5,
  "game_scores": {
    "fore_drive": { "score": 4, "lost_score": 2 },
    "back_drive": { "score": 1, "lost_score": 3 }
  }
}
```

**フォームページ（`_form.html.erb`）での動作**:
- `connect()`: localStorage に保存データがあり、かつ `draft_id` が一致する場合、各スコア入力フィールドを復元
- `saveState()`: 全フォームフィールドを収集して localStorage に保存
- `beforeunload` イベントで `saveState()` を呼ぶ
- 30秒ごとに `saveState()` を呼ぶ定期保存タイマー
- 「途中で中断する」クリック時 or 「試合を分析する」送信時に localStorage をクリア

**一覧ページ（`index.html.erb`）での動作**:
- `connect()` 時に localStorage を確認
- データがあれば「自動保存データが存在します」バナーを表示
  - `draft_id` が存在: `new_match_info_path(draft_id: X)` へリンク
  - `draft_id` なし: `restore_autosave_match_infos_path` へ POST（メタデータ + partial_scores を送信）
- 「続きから入力」クリック後に localStorage をクリア

**新規アクション `restore_autosave`**:
```ruby
def restore_autosave
  # paramsからメタデータとgame_scoresを受け取り、draft MatchInfoを作成
  find_or_create_players_from_params
  @match_info = MatchInfo.new(match_info_base_params.merge(draft: true, user: current_user))
  @match_info.partial_game_data = JSON.parse(params[:game_scores] || '{}')
  @match_info.save!
  redirect_to new_match_info_path(draft_id: @match_info.id)
end
```

### F17: 編集ページの得点板位置変更

**対象ファイル**: `app/views/match_infos/_form_edit.html.erb`

**現在の順序** (38〜100行目付近):
1. メタデータ（日付・大会名・選手名・メモ）
2. **得点板** (43-45行目: `render 'match_infos/scoreboard'`)
3. ゲーム別得点編集 見出し（71-76行目）
4. ゲームタブ（78行目〜）

**変更後の順序**:
1. メタデータ
2. ゲーム別得点編集 見出し
3. **得点板** ← ここに移動
4. ゲームタブ

変更: `render 'match_infos/scoreboard'` の記述（43-45行目）を見出しブロック（71-76行目）の直後、タブ（78行目）の直前に移動する。

## ルーティング変更

```ruby
# config/routes.rb
resources :match_infos do
  collection do
    post :end_game
    delete :undo_game
    post :interrupt        # NEW
    post :restore_autosave # NEW
  end
end
```

## 変更ファイル一覧

| ファイル | 変更種別 | 内容 |
|----------|---------|------|
| `db/migrate/YYYYMMDD_add_partial_game_data_to_match_infos.rb` | 新規 | partial_game_data JSONBカラム追加 |
| `config/routes.rb` | 修正 | interrupt, restore_autosave ルート追加 |
| `app/controllers/match_infos_controller.rb` | 修正 | interrupt/restore_autosave アクション追加、end_game/setup_draft_form 修正 |
| `app/views/match_infos/_form.html.erb` | 修正 | 途中中断ボタン変更、@partial_scores による初期値設定、auto_save data 属性追加 |
| `app/views/match_infos/_form_edit.html.erb` | 修正 | 得点板の位置を変更（見出しとタブの間に移動） |
| `app/views/match_infos/index.html.erb` | 修正 | 自動保存バナー追加、auto_save コントローラー接続 |
| `app/javascript/controllers/auto_save_controller.js` | 新規 | localStorage 自動保存・復元ロジック |

## 検証方法

### F14/F15 検証
1. 新規分析フォームを開く（1ゲーム目）
2. フォアドライブの得点を4、失点を2に設定する
3. 「途中で中断する」ボタンをクリック → 一覧ページへリダイレクトされること
4. 一覧ページで対象の試合に「続きから入力」ボタンが表示されること
5. 「続きから入力」をクリック → フォアドライブが得点4・失点2の状態で表示されること
6. 2ゲーム目以降でも同様に動作すること（1〜7ゲーム全て）

### F16 検証
1. 分析フォームで2ゲーム目にデータを入力する（フォアドライブ: 得点5、バックドライブ: 失点3）
2. ブラウザタブを強制的に閉じる（または `location.reload()` でシミュレート）
3. 一覧ページを開く → 「自動保存データがあります」バナーが表示されること
4. 「続きから入力」をクリック → 分析フォームが大会情報・技術別スコア込みで復元されること

### F17 検証
1. 既存の分析データの編集ページを開く
2. 得点板が「ゲーム別得点編集」見出しとゲームタブの間に表示されること

### RSpec / RuboCop
```bash
bundle exec rspec && bundle exec rubocop --parallel
```
