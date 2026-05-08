# Sprint 2 動作確認後の修正プラン

## Context

Sprint 2 の動作確認の結果、2点の修正が必要と判明した。

1. 説明文に旧来の「フォアドライブ」という記述が残っており、Sprint 1 で追加した正式名称「対上回転フォアドライブ」に統一する必要がある。
2. 分析編集ページ（edit）の技術名がセレクトボックスで表示されており、文字数の多い「対上回転フォアドライブ」などが表示しきれていない。新規分析ページ（new）と同様にテキスト固定表示に変更する。

---

## 変更内容

### 修正1: 説明文の「フォアドライブ」→「対上回転フォアドライブ」（4箇所）

**ファイル:** `app/views/match_infos/_form.html.erb`

- 88行目: `フォアドライブで得点 → フォアドライブの得点数` → `対上回転フォアドライブで得点 → 対上回転フォアドライブの得点数`
- 89行目: `フォアドライブで失点 → フォアドライブの失点数` → `対上回転フォアドライブで失点 → 対上回転フォアドライブの失点数`

**ファイル:** `app/views/match_infos/_form_edit.html.erb`

- 142行目: 同上
- 143行目: 同上

---

### 修正2: 編集ページの技術名をセレクトボックス→テキスト固定表示に変更

**ファイル:** `app/views/match_infos/_form_edit.html.erb`

**方針:**
- ファイル先頭に `batting_style_names` ハッシュを追加（`_form.html.erb` と同様）
- セレクトボックス（`score_form.select :batting_style`）を以下に置き換える
  - `<div class="mb-2 fw-bold">テキスト表示</div>`（技術名）
  - `score_form.hidden_field :batting_style`（値の送信用）

**対象箇所（2箇所）:**

1. **ゲームがある場合 (115-128行目)**: `game.scores` をループしてゲームごとのスコアを編集するセクション
   - 120-123行目のセレクトボックスをテキスト + hidden_field に変更

2. **ゲームがない場合 (149-170行目)**: `match_info.scores` をループしてスコアを直接編集するセクション
   - 152-155行目のセレクトボックスをテキスト + hidden_field に変更

**変更前（2箇所共通）:**
```erb
<div class="batting-style-card card mb-3 p-3">
  <%= score_form.select :batting_style,
      batting_style_options,
      {},
      { class: "form-control medium-input" } %>
  <%= render 'scores/score_fields', score_form: score_form, score: score %>
</div>
```

**変更後（2箇所共通）:**
```erb
<div class="batting-style-card card mb-3 p-3">
  <div class="mb-2 fw-bold"><%= batting_style_names[score.batting_style] || score.batting_style %></div>
  <%= score_form.hidden_field :batting_style %>
  <%= render 'scores/score_fields', score_form: score_form, score: score %>
</div>
```

---

## 検証方法

1. `bundle exec rspec` でテスト全パス確認
2. `bundle exec rubocop --parallel` でLintパス確認
3. ブラウザで新規分析ページ（/match_infos/new）の説明文を確認 → 「対上回転フォアドライブ」になっていること
4. ブラウザで分析編集ページ（/match_infos/:id/edit）を開き、技術名がセレクトボックスではなくテキスト表示になっていること
5. 編集ページでスコアを変更して保存し、正常に保存されることを確認
