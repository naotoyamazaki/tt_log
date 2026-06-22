# Sprint 2 UI修正プラン

## Context

Sprint 2で実装したサーブ・レシーブ分析フローのUX改善。ボタンラベル・配置の修正、回転選択の排他制御、サービスエース／レシーブエースの追加が目的。

---

## 変更内容と実装詳細

### 1. 試合分析一覧ページのボタン変更・位置入れ替え

**対象ファイル**: `app/views/match_infos/index.html.erb`（3〜6行目）

- 「試合分析を開始」→「技術別得点率分析を開始」に変更
- 順序を入れ替え：左に「サーブ・レシーブ分析を開始」、右に「技術別得点率分析を開始」

```erb
<div class="d-flex justify-content-center gap-2 mb-3">
  <%= link_to "サーブ・レシーブ分析を開始", new_serve_receive_match_infos_path, class: "btn btn-primary" %>
  <%= link_to "技術別得点率分析を開始", new_match_info_path, class: "btn btn-success" %>
</div>
```

---

### 2. 回転選択の排他制御

**対象ファイル**: `app/javascript/controllers/serve_receive_input_controller.js`

`toggleSpin()` メソッドに排他ロジックを追加：
- 下回転(spin=0) を選択したら 上回転(spin=1) を強制解除
- 上回転(spin=1) を選択したら 下回転(spin=0) を強制解除
- 順横回転(spin=3) を選択したら 逆横回転(spin=4) を強制解除
- 逆横回転(spin=4) を選択したら 順横回転(spin=3) を強制解除

```javascript
toggleSpin(event) {
  const spin = parseInt(event.currentTarget.dataset.spin)
  const idx = this.selectedSpins.indexOf(spin)
  if (idx === -1) {
    // 排他制御
    const exclusions = { 0: 1, 1: 0, 3: 4, 4: 3 }
    if (exclusions[spin] !== undefined) {
      this.selectedSpins = this.selectedSpins.filter(s => s !== exclusions[spin])
    }
    this.selectedSpins.push(spin)
  } else {
    this.selectedSpins.splice(idx, 1)
  }
  this.updateSpinButtons()
}
```

---

### 3. 回転ボタン選択状態のスタイル改善

**対象ファイル**: `app/assets/stylesheets/match_infos.scss`

`.rally-style-btn` に `.active` 状態のスタイルを追加。ホバー時と同じグリーンが選択時に保持されるようにする：

```scss
.rally-style-btn {
  // 既存スタイルはそのまま
  &:hover, &.active {
    background: var(--tt-primary);
    color: #fff;
    border-color: var(--tt-primary);
  }
}
```

現在の定義（`&:hover` のみ）に `&.active` を追記。

---

### 4. サービスエース・レシーブエースの追加

#### 4-1. モデルに新 enum 値を追加

**対象ファイル**: `app/models/serve_receive_pattern.rb`

`attack_style` enum に2値を追加（既存値は変更なし）：

```ruby
enum :attack_style, {
  # ... 既存 ...
  net_or_edge: 21,
  service_ace: 22,   # 追加
  receive_ace: 23    # 追加
}, prefix: :attack
```

`RECEIVE_STYLE_VALUES` 定数への追加は不要（receive_ace はサーブ側のパターンに存在しない）。

#### 4-2. JavaScript の定数・ボタン描画を更新

**対象ファイル**: `app/javascript/controllers/serve_receive_input_controller.js`

**定数に追加：**
```javascript
const BATTING_STYLE_NAMES = {
  // ... 既存 ...
  service_ace: 'サービスエース',
  receive_ace: 'レシーブエース'
}
```

`ATTACK_STYLES` 配列は `serve`/`receive` を除いた全キーを使うため、自動的に新値が含まれる。

**`renderAttackButtons()` を修正：**

3球目ボタン群（`serveAttackButtonsTarget`）の先頭に「サービスエース」ボタンを追加。アクションハンドラーは `selectServiceAce`（通常の `selectServeAttack` とは別）：

```javascript
// 3球目ボタン（serveAttackButtonsTarget）
const serviceAceBtn = `<button type="button" class="btn rally-style-btn rally-style-btn--ace"
  data-action="click->serve-receive-input#selectServiceAce">サービスエース</button>`
const attackHtml = serviceAceBtn + ATTACK_STYLES
  .filter(s => s !== 'service_ace' && s !== 'receive_ace')
  .map(style => `<button ...>...</button>`)
  .join('')

// 4球目ボタン（receiveAttackButtonsTarget）
const receiveAceBtn = `<button type="button" class="btn rally-style-btn rally-style-btn--ace"
  data-action="click->serve-receive-input#selectReceiveAce">レシーブエース</button>`
const receiveAttackHtml = receiveAceBtn + ATTACK_STYLES
  .filter(s => s !== 'service_ace' && s !== 'receive_ace')
  .map(...)
  .join('')
```

**新メソッドを追加：**

```javascript
selectServiceAce() {
  const pattern = {
    origin: this.draft.origin,
    serve_length: this.draft.serve_length || null,
    serve_spins: this.draft.serve_spins || [],
    receive_style: null,
    attack_style: 'service_ace',
    decided_at: 'attack_ball',
    won: true
  }
  this._commitPattern(pattern)
}

selectReceiveAce() {
  const pattern = {
    origin: this.draft.origin,
    serve_length: null,
    serve_spins: [],
    receive_style: this.draft.receive_style || null,
    attack_style: 'receive_ace',
    decided_at: 'attack_ball',
    won: true
  }
  this._commitPattern(pattern)
}

_commitPattern(pattern) {
  this.patterns.push(pattern)
  this.draft = {}
  this.selectedSpins = []
  this.showStep('origin')
  this.renderPatternList()
  this.updateScore()
  this.updateEndGameButton()
  this.serializePatterns()
  this.dispatchScoreUpdated()
}
```

`selectResult()` 内の重複ロジックも `_commitPattern()` を呼ぶようにリファクタ。

#### 4-3. I18n 翻訳を追加

**対象ファイル**: `config/locales/ja.yml`

`attack_style` の翻訳セクションに追加（既存の `decided_at` 翻訳などと同じ階層）：

```yaml
serve_receive_pattern:
  attack_style:
    service_ace: サービスエース
    receive_ace: レシーブエース
```

---

### 5. 「（決まった技術）」ラベル削除

**対象ファイル**: `app/views/match_infos/_serve_receive_input.html.erb`

- 82行目: `「3球目は？（決まった技術）」` → `「3球目は？」`
- 106行目: `「4球目は？（決まった技術）」` → `「4球目は？」`

---

### 6. RSpec テスト更新

**対象ファイル**: `spec/models/serve_receive_pattern_spec.rb`

- `service_ace` と `receive_ace` が `attack_style` enum に含まれることをテスト
- `allowed_attack_styles` に新値が含まれることを確認

---

## 変更ファイル一覧

| ファイル | 変更内容 |
|---------|---------|
| `app/views/match_infos/index.html.erb` | ボタンラベル変更・順序入れ替え |
| `app/views/match_infos/_serve_receive_input.html.erb` | 「（決まった技術）」ラベル削除 |
| `app/javascript/controllers/serve_receive_input_controller.js` | 排他制御、エース選択、_commitPatternリファクタ |
| `app/assets/stylesheets/match_infos.scss` | `.rally-style-btn.active` スタイル追加 |
| `app/models/serve_receive_pattern.rb` | `service_ace`・`receive_ace` enum追加 |
| `config/locales/ja.yml` | 新enum値の翻訳追加 |
| `spec/models/serve_receive_pattern_spec.rb` | 新enum値のテスト追加 |

マイグレーションは不要（`attack_style` は整数カラムで、Railsのenum定義のみ変更）。

---

## 検証方法

1. `bin/dev` でサーバー起動
2. 試合分析一覧ページ（`/match_infos`）でボタン表示・順序を確認
3. サーブ・レシーブ分析フォームで：
   - 回転選択：下回転選択後に上回転を押したら下回転が外れることを確認
   - 回転選択：選択済みボタンがグリーンで保持されることを確認
   - 3球目で「サービスエース」を押したら即座に次のラリーへ進むことを確認
   - 4球目で「レシーブエース」を押したら即座に次のラリーへ進むことを確認
   - サービスエース選択後、入力済みパターン一覧に「自分の得点」として表示されることを確認
4. `bundle exec rspec && bundle exec rubocop --parallel` で全テスト・Lintがパスすることを確認
