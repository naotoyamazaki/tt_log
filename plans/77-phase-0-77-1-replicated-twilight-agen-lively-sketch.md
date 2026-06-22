# Sprint 2 UI修正プラン（第2弾）

## Context

Sprint 2 実装後の動作確認で発覚した2点の UX 課題を修正する。
1. レシーブからの4球目選択後に「レシーブミス」の選択肢がなく、相手得点として即時記録できない
2. 「結果は？」の6ボタンが横1行に並んでいてテキストが読みづらい（縦長ボタン問題）

---

## 変更内容と実装詳細

### 1. 「レシーブミス」ボタンの追加

**概要**: 4球目選択画面（stepReceiveAttack）の先頭に「レシーブミス」ボタンを追加。押したら即座に「相手の得点」として記録し、次のラリーへ進む。`selectServiceAce` / `selectReceiveAce` と同じパターンで実装する。

#### 1-1. モデルに新 enum 値を追加

**対象ファイル**: `app/models/serve_receive_pattern.rb`

```ruby
enum :attack_style, {
  # ... 既存 ...
  service_ace: 22,
  receive_ace: 23,
  receive_miss: 24   # 追加
}, prefix: :attack
```

#### 1-2. JavaScript 定数・ボタン描画・メソッドを更新

**対象ファイル**: `app/javascript/controllers/serve_receive_input_controller.js`

**BATTING_STYLE_NAMES に追加:**
```javascript
receive_miss: 'レシーブミス'
```

**`renderAttackButtons()` の receiveAttackButtonsTarget 部分を修正:**
```javascript
// 先頭にレシーブエース・レシーブミスの2ボタンを追加
const receiveAceBtn = `<button ... data-action="...#selectReceiveAce">レシーブエース</button>`
const receiveMissBtn = `<button ... class="btn rally-style-btn rally-style-btn--miss"
  data-action="click->serve-receive-input#selectReceiveMiss">レシーブミス</button>`
const receiveAttackHtml = receiveAceBtn + receiveMissBtn + regularStyles.map(...).join('')
```

**新メソッドを追加:**
```javascript
selectReceiveMiss() {
  this._commitPattern({
    origin: this.draft.origin,
    serve_length: null,
    serve_spins: [],
    receive_style: this.draft.receive_style || null,
    attack_style: 'receive_miss',
    decided_at: 'attack_ball',
    won: false   // 相手の得点
  })
}
```

#### 1-3. スタイル追加

**対象ファイル**: `app/assets/stylesheets/match_infos.scss`

`.rally-style-btn--miss` クラスを追加（赤系で視覚的に「失点」を表す）:
```scss
.rally-style-btn--miss {
  font-weight: bold;
  background: #fee2e2;
  color: #ef4444;
  border-color: #ef4444;

  &:hover {
    background: #ef4444;
    color: #fff;
    border-color: #ef4444;
  }
}
```

#### 1-4. I18n 翻訳を追加

**対象ファイル**: `config/locales/ja.yml`

```yaml
attack_style:
  service_ace: サービスエース
  receive_ace: レシーブエース
  receive_miss: レシーブミス   # 追加
```

#### 1-5. RSpec テスト追加

**対象ファイル**: `spec/models/serve_receive_pattern_spec.rb`

- `receive_miss` が `attack_style` enum に含まれること
- `receive_miss` が24番として定義されていること

---

### 2. 「結果は？」ボタンのレイアウト変更（6列1行 → 2列3行）

**概要**: 6個の結果ボタンを「決まったタイミング」でペアにして2列3行に並べ替える。合わせてボタンのラベルを分かりやすいテキストに変更する。

**新しいボタン配置:**

| 左（自分の得点） | 右（相手の得点） |
|----------------|----------------|
| 3球目で自分が得点 | 3球目ミスで失点 |
| 5球目で自分が得点 | 5球目ミスで失点 |
| 7球目以降で得点   | 7球目以降で失点 |

#### 2-1. HTML のボタン順序・ラベルを変更

**対象ファイル**: `app/views/match_infos/_serve_receive_input.html.erb`

現在: 自分得点3つ → 相手得点3つ の順  
変更後: decided_at でペアにした順（attack → follow → rally の各行で左=won、右=lost）

```erb
<%# 結果6ボタン — 2列3行 %>
<div class="rally-step d-none" data-serve-receive-input-target="stepResult">
  <div class="rally-step-title mb-2">結果は？</div>
  <div class="rally-result-buttons">
    <%# 行1: attack_ball %>
    <button ... data-won="true"  data-decided-at="attack_ball">3球目で自分が得点</button>
    <button ... data-won="false" data-decided-at="attack_ball">3球目ミスで失点</button>
    <%# 行2: follow_ball %>
    <button ... data-won="true"  data-decided-at="follow_ball">5球目で自分が得点</button>
    <button ... data-won="false" data-decided-at="follow_ball">5球目ミスで失点</button>
    <%# 行3: rally %>
    <button ... data-won="true"  data-decided-at="rally">7球目以降で得点</button>
    <button ... data-won="false" data-decided-at="rally">7球目以降で失点</button>
  </div>
  ...
</div>
```

#### 2-2. CSS を CSS Grid に変更

**対象ファイル**: `app/assets/stylesheets/match_infos.scss`

`.rally-winner-buttons` を廃止し `.rally-result-buttons` を追加（既存クラス名を変えてもよい）:

```scss
.rally-result-buttons {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.5rem;

  @media (max-width: 480px) {
    grid-template-columns: 1fr;   // 極小画面のみ1列
  }
}
```

`.rally-winner-btn` / `.rally-winner-player` / `.rally-winner-opponent` は既存スタイルを流用（`flex: 1` → `width: 100%` への変更のみ）。

---

## 変更ファイル一覧

| ファイル | 変更内容 |
|---------|---------|
| `app/models/serve_receive_pattern.rb` | `receive_miss: 24` enum 追加 |
| `app/javascript/controllers/serve_receive_input_controller.js` | `BATTING_STYLE_NAMES` 追加、`renderAttackButtons()` 修正、`selectReceiveMiss()` 追加 |
| `app/views/match_infos/_serve_receive_input.html.erb` | 結果ボタンの順序・ラベル変更、コンテナクラス変更 |
| `app/assets/stylesheets/match_infos.scss` | `.rally-result-buttons` (grid 2列) 追加、`.rally-style-btn--miss` 追加 |
| `config/locales/ja.yml` | `receive_miss` 翻訳追加 |
| `spec/models/serve_receive_pattern_spec.rb` | `receive_miss` enum テスト追加 |

マイグレーションは不要（整数カラムの enum 定義のみ変更）。

---

## 検証方法

1. `bin/dev` でサーバー起動
2. サーブ・レシーブ分析フォームで：
   - レシーブ技術を選択後の4球目画面に「レシーブミス」ボタンが先頭（赤色）に表示されることを確認
   - 「レシーブミス」を押したら即座に「相手の得点」として入力済みパターン一覧に表示され、次のラリーへ進むことを確認
   - 「結果は？」画面のボタンが2列3行（攻撃/攻撃失点, 続球/続球失点, ラリー/ラリー失点）で横長に表示されることを確認
   - サーブ起点・レシーブ起点どちらのフローでも結果画面が2列3行になることを確認
3. `bundle exec rspec && bundle exec rubocop --parallel` で全テスト・Lintがパスすることを確認
