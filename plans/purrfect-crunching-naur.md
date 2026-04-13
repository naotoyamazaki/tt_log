# オートコンプリート機能 設計書

## Context

`index.html.erb` の検索フォームにはオートコンプリートの仕組みが既に存在するが、以下の問題で**動作しない状態**：
- コントローラの `MatchInfo.search` メソッドが存在しない
- Stimulus コントローラが `stimulus-autocomplete` ライブラリの使い方を誤っている（ライブラリ自体がStimulusコントローラなのに、別のコントローラ内で手動インスタンス化している）
- 3つのフィールドが同じエンドポイントを使い、フィールドの種類を区別していない
- ルートが重複定義されている
- レスポンスがJSON形式だが、`stimulus-autocomplete` v3.x はHTML断片を期待する

**ゴール**: 各検索フィールド（大会名・選手名・対戦相手名）にフィールドごとの候補を表示する、正しく動作するオートコンプリート機能を実装する。候補はログインユーザーのデータのみに限定する。

---

## 修正対象ファイル

| ファイル | 操作 |
|---|---|
| `config/routes.rb` | 重複ルート削除 |
| `app/controllers/match_infos_controller.rb` | `autocomplete` アクション書き換え |
| `app/views/match_infos/_autocomplete_results.html.erb` | **新規作成** - HTML断片パーシャル |
| `app/views/match_infos/index.html.erb` | 検索フォームのHTML構造変更 |
| `app/javascript/controllers/autocomplete_controller.js` | **削除** |
| `app/javascript/controllers/index.js` | ライブラリ直接登録 |
| `app/assets/stylesheets/match_infos.scss` | ドロップダウンCSS追加 |

---

## Step 1: ルート修正 (`config/routes.rb`)

重複している `get :autocomplete, on: :collection`（15行目と17行目）を1つに統合。

## Step 2: コントローラ書き換え (`match_infos_controller.rb`)

`autocomplete` アクションを以下に置き換え：

```ruby
def autocomplete
  query = "%#{params[:q]}%"
  candidates = case params[:field]
               when "match_name"
                 current_user.match_infos
                   .where("match_name ILIKE ?", query)
                   .distinct.pluck(:match_name)
               when "player_name"
                 Player.joins(:match_infos_as_player)
                   .where(match_infos: { user_id: current_user.id })
                   .where("players.player_name ILIKE ?", query)
                   .distinct.pluck(:player_name)
               when "opponent_name"
                 Player.joins(:match_infos_as_opponent)
                   .where(match_infos: { user_id: current_user.id })
                   .where("players.player_name ILIKE ?", query)
                   .distinct.pluck(:player_name)
               else
                 []
               end

  render partial: "match_infos/autocomplete_results", locals: { candidates: candidates.first(10) }
end
```

ポイント：
- `field` パラメータで検索対象を分岐（`case` で許可値を制限 → SQLインジェクション防止）
- `current_user` でスコープ限定
- `ILIKE` でPostgreSQLの大文字小文字を無視した検索
- `.first(10)` で候補数を制限
- HTML断片をレスポンス（JSON ではなく）

## Step 3: パーシャル新規作成 (`_autocomplete_results.html.erb`)

```erb
<% candidates.each do |candidate| %>
  <li role="option" data-autocomplete-value="<%= candidate %>"><%= candidate %></li>
<% end %>
```

`stimulus-autocomplete` が期待する `role="option"` + `data-autocomplete-value` の形式。

## Step 4: Stimulus コントローラ変更

**削除**: `app/javascript/controllers/autocomplete_controller.js`

**変更**: `app/javascript/controllers/index.js` にライブラリを直接登録：

```javascript
import { Autocomplete } from "stimulus-autocomplete"
application.register("autocomplete", Autocomplete)
```

`stimulus-autocomplete` はそれ自体がStimulusコントローラなので、ラッパーは不要。

## Step 5: ビュー書き換え (`index.html.erb`)

各検索フィールドのHTML構造を `stimulus-autocomplete` の期待するDOM構造に変更：

```erb
<div class="input-group"
     data-controller="autocomplete"
     data-autocomplete-url-value="<%= autocomplete_match_infos_path(field: 'match_name') %>"
     data-autocomplete-min-length-value="1">
  <span class="input-group-text"><i class="fas fa-trophy"></i></span>
  <%= f.search_field :match_name_cont, id: "match_name", class: "form-control",
      placeholder: "大会名", data: { autocomplete_target: "input" } %>
  <ul class="autocomplete-results list-group" data-autocomplete-target="results" hidden></ul>
</div>
```

構造のポイント：
- `data-controller="autocomplete"` をラッパー `div` に配置（input ではなく）
- `data-autocomplete-url-value` に `field` パラメータを含めたURL
- input に `data-autocomplete-target="input"`
- `<ul>` に `data-autocomplete-target="results"` + `hidden`
- 3フィールドとも同じ構造（`field` パラメータのみ異なる）

## Step 6: CSS追加 (`match_infos.scss`)

```scss
[data-controller="autocomplete"] {
  position: relative;

  .autocomplete-results {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    z-index: 1000;
    max-height: 200px;
    overflow-y: auto;
    background: white;
    border: 1px solid #dee2e6;
    border-radius: 0.25rem;
    margin-top: 2px;
    padding: 0;

    li[role="option"] {
      padding: 0.5rem 0.75rem;
      cursor: pointer;
      list-style: none;

      &:hover, &.active {
        background-color: #0d6efd;
        color: white;
      }
    }
  }
}
```

---

## 検証方法

1. `bin/dev` でサーバー起動
2. ログイン後、試合分析一覧ページ (`/match_infos`) にアクセス
3. 各フィールドに1文字以上入力し、ドロップダウンに候補が表示されることを確認：
   - 大会名フィールド → 大会名の候補
   - 選手名フィールド → 選手名の候補
   - 対戦相手名フィールド → 対戦相手名の候補
4. 候補をクリックしてフィールドに値が入ることを確認
5. 検索ボタンで正常にRansack検索が実行されることを確認
6. ブラウザのネットワークタブで `/match_infos/autocomplete?field=xxx&q=yyy` のリクエスト・レスポンスを確認
7. `bundle exec rspec` でテストが通ることを確認
