# Sprint 4 — UX強化 ＋ AI連携（feature/sprint-4-serve-receive-ux）

## Context

Sprint 1〜3でサーブ・レシーブ分析の**データ基盤・入力フロー・分析ページ**が完成した。
Sprint 4では試合入力の**中断・復帰・前ゲームに戻る・自動保存**を既存 technique フローと同水準に揃え、
さらに**AI アドバイス連携**と**index カードのバッジ表示**を追加する。

---

## 現状の把握（実装済み・未実装）

| 機能 | 状態 |
|------|------|
| `_serve_receive_form.html.erb` の「前のゲームに戻る」ボタン | ✅ 存在するが動作不完全 |
| `undo_game` のserve_receiveリダイレクト先 | ❌ `new_match_info_path` に飛んでしまう |
| patterns の `partial_game_data` 復元 | ❌ 未実装 |
| `_serve_receive_form.html.erb` の「途中で中断する」ボタン | ❌ 未追加 |
| `interrupt` アクションのserve_receive対応 | ❌ `game_score_params` を保存してしまう |
| `auto-save` Stimulus連携 | ❌ フォームに `auto-save` controller 未追加 |
| `restore_autosave` のserve_receiveリダイレクト | ❌ `new_match_info_path` に飛んでしまう |
| 中断後の patterns 復元（`new_serve_receive` 起動時） | ❌ 未実装 |
| index カードの analysis_type バッジ | ❌ 未実装 |
| `ServeReceiveContextBuilder` サービス | ❌ 未実装 |
| `show` アクションでのAIアドバイス生成（serve_receive時） | ❌ スキップされている |
| `show.html.erb` でのAIアドバイス表示（serve_receive時） | ❌ 未表示 |

---

## 実装タスク（上から順番に実装）

### T1: index カードに analysis_type バッジを追加

**ファイル**: `app/views/match_infos/_match_info_summary.html.erb`

「下書き」バッジの横に「サーブ・レシーブ」バッジを追加する。
draft でない場合でも表示する。

```erb
<% if match_info.serve_receive? %>
  <span class="badge bg-info text-dark ms-1">サーブ・レシーブ</span>
<% end %>
```

---

### T2: 中断機能のserve_receive対応

**対象ファイル**: 2ファイル

#### 2-1. `_serve_receive_form.html.erb` に「途中で中断する」ボタンを追加

`_form.html.erb`（lines 106-111）を参考に、`create_serve_receive` フォームの末尾に追加。
`formaction: interrupt_match_infos_path`、クラスは `btn-outline-secondary`。
（`auto-save#clearStorage` との連携はT4で追加）

#### 2-2. `interrupt` アクションの分岐追加

**ファイル**: `app/controllers/match_infos_controller.rb`（line 54〜62）

現状は `game_score_params.to_h` を保存している。
`params[:patterns].present?` で分岐し、serve_receive 時はパターンを保存：

```ruby
@match_info.partial_game_data = if params[:patterns].present?
  { 'patterns' => params[:patterns], 'first_server' => params[:first_server] }
else
  game_score_params.to_h
end
```

また、`draft_or_new_match_info` が返す MatchInfo に `analysis_type` を引き継ぐため、
`_serve_receive_form.html.erb` に `hidden_field_tag 'match_info[analysis_type]', 'serve_receive'` を追加し、
`basic_match_info_params`（または `match_info_params`）に `:analysis_type` を permit 追加。

---

### T3: undo_game のserve_receive対応

**ファイル**: `app/controllers/match_infos_controller.rb`（line 72〜78 および private）

#### 3-1. `undo_game` アクションに分岐を追加

```ruby
def undo_game
  @match_info = current_user.match_infos.find_by(id: params[:draft_id])
  return redirect_to new_match_info_path unless @match_info

  if @match_info.serve_receive?
    restore_last_serve_receive_to_partial_data(@match_info)
    redirect_to new_serve_receive_match_infos_path(draft_id: @match_info.id)
  else
    restore_last_game_to_partial_data(@match_info)
    redirect_to new_match_info_path(draft_id: @match_info.id)
  end
end
```

#### 3-2. 新 private メソッド `restore_last_serve_receive_to_partial_data`

`restore_last_game_to_partial_data`（line 339）の鏡像。

1. `last_game = match_info.games.order(:game_number).last`
2. `patterns = match_info.serve_receive_patterns.where(game_number: last_game.game_number).order(:sequence_number)` で該当ゲームのパターン取得
3. patterns を `[{origin:, serve_length:, serve_spins:, receive_style:, attack_style:, decided_at:, won:}]` 形式でマップし JSON化
4. `match_info.partial_game_data = { 'patterns' => patterns.to_json, 'first_server' => last_game.first_server }`
5. `serve_receive_patterns.where(game_number: last_game.game_number).destroy_all`
6. `last_game.destroy`
7. `match_info.save!(validate: false)`

#### 3-3. `_serve_receive_form.html.erb` の patterns 初期復元対応

`setup_draft_form` の `@partial_scores` に patterns が入るため、フォームで読み出す：

```erb
<% initial_patterns_json = @partial_scores&.dig('patterns') || '[]' %>
<% initial_first_server_partial = @partial_scores&.dig('first_server') %>
```

Stimulus コントローラへ渡す `initial-patterns-value` を追加：
```erb
data: { controller: "scoreboard serve-receive-input",
        "serve-receive-input-initial-patterns-value": initial_patterns_json,
        "serve-receive-input-initial-first-server-value": (initial_first_server || initial_first_server_partial).to_s }
```

`serve_receive_input_controller.js` で `initialPatternsValue` を読み込み、patterns 配列の初期値として復元するロジックを追加（`connect()` 内 or `initialize()` 内で `JSON.parse(this.initialPatternsValue)` → `this.patterns` にセット、`renderPatternList()` と `updateScore()` を呼ぶ）。

---

### T4: auto_save の serve_receive 対応

**対象ファイル**: 3ファイル

#### 4-1. `_serve_receive_form.html.erb` に `auto-save` controller を追加

```erb
data: { controller: "scoreboard auto-save serve-receive-input",
        auto_save_draft_id_value: draft_id.to_s,
        ... }
```

`auto-save` controller が localStorage に保存するフィールドの確認（`auto_save_controller.js`）。
serve_receive フォームでは `patterns`（hidden field）と各テキストフィールドが対象。
必要であれば `auto-save` controller に `patternsField` target を追加、または `serialized` target で対応。

#### 4-2. `restore_autosave` アクションの分岐追加

**ファイル**: `app/controllers/match_infos_controller.rb`（line 64〜70）

`params[:analysis_type]` を受け取り、serve_receive の場合は専用パスにリダイレクト：

```ruby
def restore_autosave
  player = Player.find_or_create_by(player_name: params[:player_name].to_s)
  opponent = Player.find_or_create_by(player_name: params[:opponent_name].to_s)
  @match_info = build_autosave_match_info(player, opponent)
  @match_info.save!(validate: false)
  if @match_info.serve_receive?
    redirect_to new_serve_receive_match_infos_path(draft_id: @match_info.id)
  else
    redirect_to new_match_info_path(draft_id: @match_info.id)
  end
end
```

`build_autosave_match_info`（line 407）: `params[:patterns].present?` の場合は `analysis_type: :serve_receive` を設定し、`partial_game_data = { 'patterns' => params[:patterns], 'first_server' => params[:first_server] }` を保存。

---

### T5: ServeReceiveContextBuilder の新規作成

**ファイル**: `app/services/serve_receive_context_builder.rb`（新規）

`RallyContextBuilder` の構造を参考に、サーブ・レシーブ分析に特化したプロンプト文を生成。

```ruby
class ServeReceiveContextBuilder
  def initialize(match_info)
    @match_info = match_info
    @analyzer = ServeReceiveAnalyzer.new(match_info)
  end

  def serve_analysis_text
    # serve_length_stats と serve_pattern_stats から文章生成
    # 例: "ショートサーブの得点率は XX%（N得点/M失点）"
    #     "最も有効なパターン: ショート 下回転 → 対下回転フォアドライブ (N得点, 得点率XX%)"
  end

  def receive_analysis_text
    # receive_direct_stats と receive_pattern_stats から文章生成
  end

  def timing_analysis_text
    # decided_at_distribution から文章生成
    # 例: "サーブ起点: 3球目決着 N点, 5球目 M点, 7球目以降 K点"
  end

  def build_context
    [
      "【サーブ起点の分析】",
      serve_analysis_text,
      "【レシーブ起点の分析】",
      receive_analysis_text,
      "【得点タイミング】",
      timing_analysis_text
    ].join("\n")
  end
end
```

各テキストメソッドは private ヘルパーで数値整形。
行数制限（20行/メソッド）に注意し、必要に応じて private に分割。

---

### T6: show アクションの AI 連携追加

**ファイル**: `app/controllers/match_infos_controller.rb`（`show` アクション、line 10〜21）

```ruby
def show
  set_match_info_scores
  if @match_info.serve_receive?
    @srp_analysis = ServeReceiveAnalyzer.new(@match_info)
    if @match_info.advice.present?
      @advice = @match_info.advice
    else
      builder = ServeReceiveContextBuilder.new(@match_info)
      advice = ChatgptService.get_serve_receive_advice(@match_info, builder)
      @match_info.update_advice(advice)
      @advice = advice
    end
  elsif @match_info.advice.present?
    @advice = @match_info.advice
  else
    advice = ChatgptService.get_advice(@match_info)
    @match_info.update_advice(advice)
    @advice = advice
  end
end
```

`ChatgptService` に `get_serve_receive_advice(match_info, builder)` を追加、または
既存 `get_advice` に `analysis_type` 分岐を追加して `builder.build_context` を使ったプロンプトを送信。

**`ChatgptService` のプロンプト分岐**（`chatgpt_service.rb`）:
- serve_receive 時: `ServeReceiveContextBuilder#build_context` で生成したコンテキストを使用
- システムプロンプトも「サーブ・レシーブ起点分析のアドバイス」特化版に変更

---

### T7: show.html.erb にAIアドバイス表示セクションを追加

**ファイル**: `app/views/match_infos/show.html.erb`

serve_receive 分岐内（`_serve_receive_analysis` render の後）にアドバイスセクションを追加：

```erb
<% if @match_info.serve_receive? %>
  <%= render 'match_infos/serve_receive_analysis', srp_analysis: @srp_analysis %>
  <% if @advice.present? %>
    <div class="show-container fade-in-up mb-4">
      <div class="section-card p-4 shadow-sm">
        <div class="advice-section">
          <%= simple_format(@advice) %>
        </div>
      </div>
    </div>
  <% end %>
<% else %>
  ...既存...
<% end %>
```

---

### T8: テスト追加

**新規**: `spec/services/serve_receive_context_builder_spec.rb`
- `serve_analysis_text`, `receive_analysis_text`, `timing_analysis_text` が空でない文字列を返すこと
- データなし時も例外を出さないこと

**既存 spec 更新**:
- `spec/requests/match_infos_spec.rb`（または controller spec）:
  - `interrupt` が serve_receive 時に `patterns` を `partial_game_data` に保存すること
  - `undo_game` が serve_receive 時に `new_serve_receive_match_infos_path` にリダイレクトすること

---

## 変更ファイル一覧

| ファイル | 変更種別 |
|---------|---------|
| `app/controllers/match_infos_controller.rb` | 編集（`show`, `interrupt`, `undo_game`, `restore_autosave` + 新 private メソッド） |
| `app/services/serve_receive_context_builder.rb` | **新規作成** |
| `app/services/chatgpt_service.rb` | 編集（serve_receive 用プロンプト分岐追加） |
| `app/views/match_infos/_serve_receive_form.html.erb` | 編集（中断ボタン追加・auto-save controller追加・初期patterns渡し） |
| `app/views/match_infos/_match_info_summary.html.erb` | 編集（analysis_type バッジ追加） |
| `app/views/match_infos/show.html.erb` | 編集（AIアドバイス表示セクション追加） |
| `app/javascript/controllers/serve_receive_input_controller.js` | 編集（initialPatternsValue の復元ロジック追加） |
| `spec/services/serve_receive_context_builder_spec.rb` | **新規作成** |
| `spec/requests/match_infos_spec.rb` | 編集（interrupt/undo_game の serve_receive ケース追加） |

---

## 流用する既存実装

| 流用元 | 目的 |
|--------|------|
| `_form.html.erb` lines 106-111 | 「途中で中断する」ボタンの実装パターン |
| `interrupt` アクション（line 54〜62） | serve_receive 分岐の追加ベース |
| `restore_last_game_to_partial_data`（line 339〜346） | `restore_last_serve_receive_to_partial_data` の実装パターン |
| `RallyContextBuilder` | `ServeReceiveContextBuilder` の構造テンプレート |
| `chatgpt_service.rb` の `get_advice` | serve_receive 用プロンプトのベース |
| `auto_save_controller.js` | serve_receive フォームへの追加（確認後流用） |

---

## 検証方法

```bash
bundle exec rspec && bundle exec rubocop --parallel
```

ブラウザ検証:
1. サーブ・レシーブ分析を開始 → 数点入力 → 「途中で中断する」→ 一覧ページに下書きが残ること
2. 下書きから再開 → 入力済みパターンが復元されていること
3. ゲーム終了後に「前のゲームに戻る」→ 前ゲームのパターンが復元されること
4. 試合を分析する → 分析ページとAIアドバイスが表示されること
5. index カードに「サーブ・レシーブ」バッジが表示されること
