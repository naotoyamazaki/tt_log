# Sprint 3 バグ修正プラン

## Context

Sprint 3 で実装した3機能（Undo・ドラフト保存・試合形式選択）の動作確認で、以下2つのバグが確認された。根本原因はどちらも同じ「HTMLネストフォーム問題」で、1つの修正で両方解消できる。

---

## 根本原因

`_form.html.erb` の `button_to` ヘルパーは **自身の `<form>` タグを生成する**。
これが外側の `form_with` ブロック内に置かれているため、HTML仕様上禁止されている**ネストフォーム**が生成される。

ブラウザはネストフォームを不正なHTMLとして扱い:
1. 内側の `<form>`（Undo ボタン）が無視される → **Bug 1: Undo が動作しない**
2. 外側の `<form>`（メインフォーム）が壊れる → **Bug 2: ゲーム終了ボタン・分析ボタンが動作しない**

Undo ボタンは `@draft_id.present? && @saved_games.any?` のときのみ描画されるため、「続きから入力」後のみ症状が現れる。

---

## 修正内容

### 対象ファイル

- `app/views/match_infos/_form.html.erb`（1箇所変更のみ）

### 変更内容

`button_to` を `link_to` + `data-turbo-method` に置き換える。

Turbo の `data-turbo-method` は一時的な form を `document.body` に直接追加して送信するため、メインフォームとのネストは発生しない。

また、`draft_id` をフォーム `params` ではなく **URLクエリパラメータ**として渡すことで、コントローラー側の変更は不要になる（`params[:draft_id]` はクエリ文字列でも取得できる）。

**変更前:**
```erb
<%= button_to "↩ 前のゲームを取り消す",
    undo_game_match_infos_path,
    method: :delete,
    params: { draft_id: @draft_id },
    data: { turbo_confirm: "直前のゲームの入力を取り消しますか？" },
    class: "btn btn-outline-warning" %>
```

**変更後:**
```erb
<%= link_to "↩ 前のゲームを取り消す",
    undo_game_match_infos_path(draft_id: @draft_id),
    data: { turbo_method: "delete", turbo_confirm: "直前のゲームの入力を取り消しますか？" },
    class: "btn btn-outline-warning" %>
```

---

## 対象外（別スプリント推奨）

「途中で中断する際の各技術スコアを保存して続きから復元する」機能は、
現在の入力中スコアを中断時点でDBまたはlocalStorageへ保存するロジックが必要で実装が複雑なため、別スプリントで実装する。

---

## ブランチ

既存の `feature/sprint-3-input-ux` で修正コミットを追加する（Sprint 3 のバグ修正のため）。

---

## 確認方法

1. `bundle exec rspec && bundle exec rubocop --parallel` がパスすること
2. `http://localhost:3000/match_infos/new` で1ゲーム目を入力し「Nゲーム目終了」を押す
3. 2ゲーム目フォームで「↩ 前のゲームを取り消す」を押すと1ゲーム目に戻ること
4. 2ゲーム目フォームで「試合を分析する」「Nゲーム目終了」が正常に動作すること
5. 「途中で中断する」→一覧の「続きから入力」→フォームが開き「Nゲーム目終了」が動作すること
