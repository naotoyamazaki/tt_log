# 実装プラン: 試合分析フォームへの得点板設置 #101

## Context

試合分析フォームページ（`match_infos/new`, `edit`）にリアルタイム得点板を設置する。  
ユーザーが各技術の得点数・失点数を入力するたびに、得点板が自動更新され、現在のゲーム数と得点状況を把握できるようにする。

**設計方針（ユーザー確認済み）**:
- 合計得点（全技術のscore合計）と合計失点（全技術のlost_score合計）からゲームをシミュレーション
- 試合形式（5ゲームマッチ/7ゲームマッチ）はフォーム上部のセレクタでDBに保存

---

## 実装ステップ

### Step 1: DBマイグレーション
**ファイル**: `db/migrate/XXXX_add_match_format_to_match_infos.rb`

```ruby
add_column :match_infos, :match_format, :integer, default: 5
```

- `match_format`: 5（5ゲームマッチ）または 7（7ゲームマッチ）
- デフォルト 5

---

### Step 2: MatchInfoモデル更新
**ファイル**: `app/models/match_info.rb`

```ruby
validates :match_format, inclusion: { in: [5, 7] }
```

---

### Step 3: コントローラー更新
**ファイル**: `app/controllers/match_infos_controller.rb`

`match_info_params` に `:match_format` を追加:
```ruby
params.require(:match_info).permit(
  :match_date, :match_name, :memo, :match_format,
  scores_attributes: [:id, :batting_style, :score, :lost_score, :_destroy]
)
```

---

### Step 4: フォームビュー更新
**ファイル**: `app/views/match_infos/_form.html.erb`（新規・編集両方）  
**ファイル**: `app/views/match_infos/_form_edit.html.erb`

#### 変更内容:
1. フォーム全体に `data-controller="scoreboard"` を追加
2. 基本情報行に試合形式セレクタを追加（match_format: 5 or 7）
3. 得点板パーシャルをスコア入力前に配置
4. 選手名・対戦相手名の入力欄に `data-scoreboard-target="playerNameInput"` / `"opponentNameInput"` を追加
5. 試合形式セレクタに `data-scoreboard-target="matchFormat" data-action="change->scoreboard#update"` を追加

**フォームレイアウト（変更後）**:
```
[基本情報: 日付・大会名・選手名・対戦相手名・試合形式]
[メモ]
[使い方説明]
[得点板 ← NEW（使い方説明の直後）]
[技術別スコア入力]
[送信ボタン]
```

---

### Step 5: 得点板パーシャル作成
**ファイル**: `app/views/match_infos/_scoreboard.html.erb`

グリーングラデーション背景（技術スコア欄と同じ `.card` スタイルを流用）・卓球スコアボード風のUI（添付画像のデザインに準拠）:

```
+--------------------------------------------------+
|  山田太郎            佐藤次郎                     |
|                                                  |
|  +------+    11 - 8    +------+                 |
|  |      |    11 - 9    |      |                 |
|  |  2   |      -       |  0   |                 |
|  |      |      -       |      |                 |
|  +------+      -       +------+                 |
|  (獲得G)   (ゲーム履歴)  (獲得G)                |
+--------------------------------------------------+
```

- `data-scoreboard-target` を各要素に付与
  - `playerName`, `opponentName`: 選手名表示
  - `playerWins`, `opponentWins`: 獲得ゲーム数（大きく表示）
  - `gameHistory`: ゲーム履歴リスト

---

### Step 6: Stimulusコントローラー作成
**ファイル**: `app/javascript/controllers/scoreboard_controller.js`

#### ターゲット定義:
```javascript
static targets = [
  "playerName", "opponentName",
  "playerWins", "opponentWins",
  "gameHistory", "matchFormat",
  "playerNameInput", "opponentNameInput"
]
```

#### 主要メソッド:

**`connect()`**: フォームにイベントリスナー登録（inputイベント）、初期表示更新

**`update()`**: スコア入力値の変更時に呼ばれる
```javascript
update() {
  const playerTotal = this.sumInputsByPattern('[name*="[score]"]')
  const opponentTotal = this.sumInputsByPattern('[name*="[lost_score]"]')
  const maxGames = parseInt(this.matchFormatTarget.value)
  const result = this.simulateMatch(playerTotal, opponentTotal, maxGames)
  this.renderScoreboard(result)
}
```

**`simulateMatch(playerTotal, opponentTotal, maxGames)`**: ゲームシミュレーション
```javascript
simulateMatch(playerTotal, opponentTotal, maxGames) {
  const winsNeeded = Math.ceil(maxGames / 2)  // 3 or 4
  let playerWins = 0, opponentWins = 0
  let pLeft = playerTotal, oLeft = opponentTotal
  const games = []

  while (playerWins < winsNeeded && opponentWins < winsNeeded) {
    if (pLeft <= 0 && oLeft <= 0) break
    const total = pLeft + oLeft
    const pRatio = total > 0 ? pLeft / total : 0.5

    let pScore, oScore
    if (pRatio >= 0.5) {
      pScore = 11
      oScore = Math.max(0, Math.min(9, Math.round(11 * (1 - pRatio) / pRatio)))
    } else {
      oScore = 11
      pScore = Math.max(0, Math.min(9, Math.round(11 * pRatio / (1 - pRatio))))
    }

    pLeft -= pScore
    oLeft -= oScore
    if (pScore > oScore) playerWins++
    else opponentWins++
    games.push({ p: pScore, o: oScore })
    if (games.length >= maxGames) break
  }

  return { playerWins, opponentWins, games, maxGames, winsNeeded }
}
```

**`renderScoreboard(result)`**: DOM更新（獲得ゲーム数・ゲーム履歴）

**`updateNames()`**: 選手名・対戦相手名の入力変更時に得点板の名前を更新

---

### Step 7: CSS追加
**ファイル**: `app/assets/stylesheets/match_infos.scss`

既存の `.card` クラス（`background: linear-gradient(135deg, #4CAF50, #1B5E20)`）を得点板コンテナに適用し、白文字で表示。追加スタイルのみ定義:

```scss
.scoreboard {
  // background は既存の .card グラデーションを使用
  color: #fff;
  padding: 24px;
  margin-bottom: 24px;

  .scoreboard-names { ... }
  .score-large { font-size: 6rem; font-weight: bold; }
  .game-history { font-size: 1rem; text-align: center; }
  .game-history-row { ... }
}
```

---

### Step 8: RSpecテスト更新
**ファイル**: `spec/models/match_info_spec.rb`

```ruby
describe 'validations' do
  it 'match_formatが5または7のみ有効であること' do
    match_info = build(:match_info, match_format: 5)
    expect(match_info).to be_valid

    match_info.match_format = 7
    expect(match_info).to be_valid

    match_info.match_format = 3
    expect(match_info).not_to be_valid
  end
end
```

---

## 変更対象ファイル一覧

| ファイル | 変更種別 |
|---------|---------|
| `db/migrate/XXXX_add_match_format_to_match_infos.rb` | 新規作成 |
| `db/schema.rb` | 自動更新 |
| `app/models/match_info.rb` | バリデーション追加 |
| `app/controllers/match_infos_controller.rb` | Strongパラメータ更新 |
| `app/views/match_infos/_form.html.erb` | data-controller, セレクタ, パーシャル追加 |
| `app/views/match_infos/_form_edit.html.erb` | 同上 |
| `app/views/match_infos/_scoreboard.html.erb` | 新規作成 |
| `app/javascript/controllers/scoreboard_controller.js` | 新規作成 |
| `app/assets/stylesheets/match_infos.scss` | スコアボードCSS追加 |
| `spec/models/match_info_spec.rb` | テスト追加 |

---

## 検証方法

```bash
# 1. マイグレーション
rails db:migrate

# 2. サーバー起動
bin/dev

# 3. ブラウザで確認
# - /match_infos/new を開く
# - 試合形式セレクタが表示されること
# - 得点板が黒背景で表示されること
# - 技術の得点/失点を入力すると獲得ゲーム数・ゲーム履歴が更新されること
# - 選手名・対戦相手名を入力すると得点板の名前も更新されること
# - 5ゲームマッチ/7ゲームマッチを切り替えて動作確認

# 4. テストとLint
bundle exec rspec && bundle exec rubocop --parallel
```
