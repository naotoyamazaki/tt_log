# 得点推移表機能（ラリー順入力 + 推移表表示）

## Context

現行の「技術ごとの得失点集計入力」では得点の時系列順序が失われるため、試合の流れや大事な局面での傾向を分析できない。
PDFのフォーマットを参考に、ラリーを1本ずつ順番に記録することで「何点目にどの技術で得点/失点したか」を可視化し、AIへの文脈情報も豊かにする。
試合後にまとめて入力する前提。技術別集計（得点率など）はラリーデータから自動計算するため既存の表示は維持される。

---

## データ設計

### 新テーブル: rallies
```
id, match_info_id, game_id (nullable), game_number, sequence_number, winner (enum: player/opponent), batting_style (enum: Scoreと同じ), timestamps
```

| 列 | 意味 |
|---|---|
| winner | その得点を取ったのが player か opponent か |
| batting_style | **得点を決めた技術**（現行と意味が変わる）|
| game_number | game_id設定前の一時番号 |

**batting_styleの意味変更について**
現行: 「自分がその技術を使用したときの得失点」
新規: 「その得点を決めた側の技術」（player の fore_drive で得点 → fore_drive.score+1 / opponent の fore_drive で得点 → fore_drive.lost_score+1）
→ 「相手のフォアドライブに5点取られた → フォアドライブへの対応を練習すべき」という解釈になり分析がより具体的になる。

---

## スプリント計画

### Sprint 1: Rallyモデル + データレイヤー

**変更ファイル:**
- `db/migrate/XXXXXX_create_rallies.rb`（新規）
- `app/models/rally.rb`（新規）
- `app/models/game.rb` → `has_many :rallies, dependent: :destroy` 追加
- `app/models/match_info.rb` → `has_many :rallies, dependent: :destroy` 追加
- `app/controllers/match_infos_controller.rb` → `end_game`/`create`/`undo_game` を更新

**実装内容:**

1. **マイグレーション**
   ```ruby
   create_table :rallies do |t|
     t.references :match_info, null: false, foreign_key: true
     t.references :game, null: true, foreign_key: true
     t.integer :game_number, null: false
     t.integer :sequence_number, null: false
     t.integer :winner, null: false      # 0: player, 1: opponent
     t.integer :batting_style, null: false
     t.timestamps
   end
   add_index :rallies, [:match_info_id, :game_number, :sequence_number], unique: true
   ```

2. **Rally モデル** (`app/models/rally.rb`)
   - `enum :winner, { player: 0, opponent: 1 }`
   - `enum :batting_style, Score.batting_styles` (同じenumを再定義)
   - validates presence of: winner, batting_style, game_number, sequence_number

3. **コントローラー修正** (`app/controllers/match_infos_controller.rb`)

   `end_game` / `create` の変更:
   - `params[:rallies]` が存在する場合 → `create_game_from_rallies` を呼ぶ
   - 存在しない場合 → 既存の `create_game_with_scores` にフォールバック（後方互換）

   ```ruby
   def create_game_from_rallies(match_info)
     rallies_data = JSON.parse(params[:rallies])  # [{winner:, batting_style:}, ...]
     game_number = match_info.games.count + 1
     player_total = rallies_data.count { |r| r['winner'] == 'player' }
     opponent_total = rallies_data.count { |r| r['winner'] == 'opponent' }
     game = match_info.games.create!(game_number: game_number, player_score: player_total, opponent_score: opponent_total)
     
     # Rally レコードを保存
     rallies_data.each_with_index do |r, i|
       match_info.rallies.create!(game_id: game.id, game_number: game_number,
         sequence_number: i + 1, winner: r['winner'], batting_style: r['batting_style'])
     end
     
     # Score レコードをラリーデータから集計
     aggregate_scores_from_rallies(match_info, game)
   end
   
   def aggregate_scores_from_rallies(match_info, game)
     rallies = game.rallies
     grouped = rallies.group_by(&:batting_style)
     grouped.each do |style, rs|
       player_wins = rs.count { |r| r.winner == 'player' }
       opponent_wins = rs.count { |r| r.winner == 'opponent' }
       match_info.scores.create!(game_id: game.id, batting_style: style,
         score: player_wins, lost_score: opponent_wins)
     end
   end
   ```

   `undo_game` の変更:
   - 現行: Scoreレコードから `partial_game_data` を再構築
   - 新規: game にRallyレコードがある場合 → Rallyデータを `partial_game_data` に保存してフォームで復元可能にする
   ```ruby
   def restore_last_game_to_partial_data(match_info)
     last_game = match_info.games.order(:game_number).last
     return unless last_game
     
     if last_game.rallies.any?
       rally_data = last_game.rallies.order(:sequence_number).map { |r| { winner: r.winner, batting_style: r.batting_style } }
       last_game.destroy  # rallies も dependent: :destroy で消える
       match_info.partial_game_data = { 'rallies' => rally_data }
     else
       # 既存のScore復元ロジックを維持
       partial_data = reconstruct_partial_data(last_game)
       last_game.destroy
       match_info.partial_game_data = partial_data
     end
     match_info.save!(validate: false)
   end
   ```

4. **RSpec**
   - `spec/models/rally_spec.rb`
   - `spec/requests/match_infos_spec.rb` にrally params対応のテストを追加

---

### Sprint 2: ラリー入力UI

**変更ファイル:**
- `app/views/match_infos/_form.html.erb` → batting-style cards グリッドを置き換え
- `app/javascript/controllers/rally_input_controller.js`（新規）
- `app/javascript/controllers/auto_save_controller.js` → rally データの save/restore 対応
- `app/javascript/controllers/scoreboard_controller.js` → rally イベントでのスコア更新に対応

**UI フロー（2ステップ入力）:**

```
[現在のスコア: 自分 3 - 相手 2]

ステップ1: 誰が得点した？
[  自分の得点  ]   [  相手の得点  ]   ← 大ボタン

ステップ2: どの技術で？（ステップ1選択後に表示）
[サーブ] [フォアドライブ] [バックドライブ] [フォアツッツキ]
[バックツッツキ] [チキータ] [フォアスマッシュ] ...
[もっと見る ▼]

──── 入力済みラリー ────
5本目: 自分 ← フォアドライブ  [↩ 取り消し]
4本目: 相手 ← サーブ
3本目: 自分 ← フォアツッツキ
...

[1ゲーム目終了]  ← 11点以上かつ2点差以上のとき有効化
```

**Stimulus controller (rally_input_controller.js) の責務:**
- 2ステップ選択状態管理
- ラリー配列のメモリ管理
- 現在スコア計算（player/opponent の個数カウント）
- ゲーム終了条件チェック: `Math.max(p, o) >= 11 && Math.abs(p - o) >= 2`
  （例: 11-9 → ✓、11-10 → ✗、12-10 → ✓、10-10 → ✗）
- ゲーム終了条件を満たしたとき `scoreboard_controller` に `rally:scoreUpdated` カスタムイベントを発火してゲーム数表示も更新
- フォーム送信時に rallies を JSON シリアライズして hidden field に設定
- undo（最後のラリーを削除）

**`_form.html.erb` の変更:**
- 従来の `Score.allowed_batting_styles.each` ブロック（行93-131）を削除
- rally input UIのpartial `_rally_input.html.erb` を挿入
- hidden field `<input type="hidden" name="rallies" data-rally-input-target="serialized">` を追加
- ゲーム終了ボタンは rally_input_controller がスコア条件を満たしたときのみ有効化
- undo_game: `partial_game_data['rallies']` があれば rally list を初期値として渡す

**auto_save_controller.js の変更:**
- 既存の score フィールド収集ロジックを rally リストの収集に置き換え

---

### Sprint 3: 得点推移表（Showページ）

**変更ファイル:**
- `app/views/match_infos/show.html.erb`
- `app/views/match_infos/_score_progression.html.erb`（新規）
- `app/assets/stylesheets/` に推移表のスタイル追加

**表示仕様（PDFと同フォーマット）:**

```
1ゲーム目
       1    2    3    4    5    6    7    8    9   10   11
選手名  [S]       [FD][BD]      [FF] [C] [FC]     [BC][FB]
相手名       [S]           [BD]           [BC]         [BB]
```

- Rallyレコードがあるゲームのみ表示（既存データは非表示のまま）
- player = 青背景、opponent = 赤背景
- 技術略称: `{ serve: 'S', fore_drive_vs_topspin: 'FD↑', back_drive_vs_topspin: 'BD↑', fore_drive_vs_backspin: 'FD↓', ... }`
- 略称セルにはツールチップ（`title` 属性 + Bootstrap tooltip）で正式名称を表示。スマホでは tap で表示。
- 横スクロール対応（スマホ考慮）
- show.html.erb 内に新しいセクションとして追加

---

### Sprint 4: AI分析強化

**変更ファイル:**
- `app/services/chatgpt_service.rb`（プロンプト全面置き換え）
- `app/services/rally_context_builder.rb`（新規）
- `app/controllers/match_infos_controller.rb`（show action に rally_context 追加）

---

#### RallyContextBuilder（新規サービス）

`app/services/rally_context_builder.rb` として実装。ラリーデータから3つの分析文脈を算出する。

```ruby
RallyContextBuilder.build(match_info)
# 戻り値:
{
  technique_efficiency: [
    { batting_style: 'fore_drive_vs_topspin', name: '対上回転フォアドライブ',
      total: 15, wins: 8, win_rate: 0.53 },
    ...
  ],  # total 降順ソート

  situation_stats: {
    leading:  { total: 20, wins: 12, win_rate: 0.60 },  # 自分+2点以上リード
    close:    { total: 35, wins: 18, win_rate: 0.51 },  # 1点差以内
    trailing: { total: 18, wins:  7, win_rate: 0.39 },  # 相手+2点以上リード
    critical: { total:  8, wins:  3, win_rate: 0.38 }   # 9-9以降
  },

  momentum: {
    losing_streaks: [  # 3連続以上の失点
      { count: 4, trigger: 'back_drive_vs_topspin', game: 1, score: '3-5' },
      ...
    ],
    recovery_techniques: ['serve', 'fore_drive_vs_topspin'],  # 連続失点後の最初の得点技術（頻度順）
    max_winning_streak: { count: 5, game: 2 },
    max_losing_streak:  { count: 4, game: 1 }
  }
}
```

**算出ロジック:**

- **technique_efficiency**: `match_info.rallies.group_by(&:batting_style)` で集計。total = グループ数、wins = winner == :player の数。
- **situation_stats**: 各ゲームのラリーを sequence_number 順に処理し、直前スコアを追跡。得点時に局面分類してカウント。
- **momentum**: ゲーム内でラリーを sequence 順に走査し、連続失点ランを検出。3連続以上を抽出。

---

#### ChatgptService プロンプト全面置き換え

**システムプロンプト（現行の1行から強化）:**
```
あなたは卓球コーチです。
データに基づき、選手が次の試合で結果を出すための具体的・実践的な改善アドバイスを日本語で提供してください。
抽象的なアドバイスは避け、「この技術をこうする」という練習・戦術レベルで回答してください。
なお、フォアプッシュはフォアツッツキ、バックプッシュはバックツッツキと表示してください。
```

**ユーザープロンプト（rally_context あり）:**
```
以下は卓球1試合のデータです。

【A. 技術別 使用頻度と勝率】
（使用頻度の高い順）
- 対上回転フォアドライブ: 15本、勝率53%
- サーブ: 12本、勝率67%
- バックドライブ: 8本、勝率38%
...

【B. スコア状況別 得点率】
- 接戦時（1点差以内）: 51%
- 先行時（+2以上リード）: 60%
- 追随時（-2以上ビハインド）: 39%
- 大事な局面（9-9以降）: 38%

【C. 連続失点パターン】
- 3連続以上の失点: 3回発生
  - 1ゲーム目 3-5（きっかけ: バックドライブ、4連続）
  - 2ゲーム目 7-8（きっかけ: サーブ、3連続）
- 連続失点後の最初の得点技術: サーブ（2回）、フォアドライブ（1回）
- 最大連続得点: 5連続（2ゲーム目）

【技術別データ（詳細）】
{batting_score_data}

【ゲーム別スコア】
{game_section}

---
上記データを踏まえ、以下3点について具体的にアドバイスしてください。

【A. 優先して練習すべき技術】
多用しているのに勝率が低い技術を特定し、改善のための具体的な練習方法を提案してください。

【B. プレッシャー下での安定性向上】
追随時・大事な局面での得点率が低い場合、その要因の仮説と、安定して得点できる戦術・精神的なアプローチを提案してください。

【C. 連続失点の防止策】
連続失点を引き起こすパターンを分析し、それを断ち切るための戦術・配球の変え方・練習方法を提案してください。

アドバイス:
```

**ユーザープロンプト（rally_context なし ＝ 既存データの後方互換）:**
現行の4項目プロンプト（得点多く失点少ない / 得点多く失点も多い / 得点少なく失点多い / 未使用技術）をそのまま維持。ゲームデータがある場合はゲームごとの傾向も追加。

**シグネチャ変更:**
```ruby
def self.get_advice(batting_score_data, game_data = nil, rally_context = nil)
```

---

#### コントローラー更新 (`show` action)

```ruby
def show
  set_match_info_scores
  rally_context = @match_info.rallies.any? ? RallyContextBuilder.build(@match_info) : nil
  if @match_info.advice.present?
    @advice = @match_info.advice
  else
    game_data = @match_info.game_by_game_score_data
    advice = ChatgptService.get_advice(@match_info.batting_score_data.to_json, game_data, rally_context)
    @match_info.update_advice(advice)
    @advice = advice
  end
end
```

編集時に batting_score が変わった場合も rally_context を渡してアドバイスを再生成する（`update_advice_if_needed` も同様に更新）。

---

## 検証方法

1. RSpec + RuboCop: `bundle exec rspec && bundle exec rubocop --parallel`
2. Playwright による動作確認:
   - 新規試合作成 → ラリーを数本入力 → 1ゲーム目終了 → 2ゲーム目以降も同様 → 試合を分析する
   - 技術別得点率の表示が正しく集計されているか確認
   - Showページに推移表が表示されるか確認
   - undo（前のゲームに戻る）でラリーリストが復元されるか確認
   - 既存データ（Rallyなし）のshow pageが壊れていないか確認
