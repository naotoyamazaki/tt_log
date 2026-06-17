# #77 サーブ・レシーブ起点の3球目/4球目パターン分析 実装設計

既存の「技術別得点率」分析とは完全独立した第二の分析機能。
試合分析一覧(`match_infos#index`)から新規作成し、ゲーム単位でサーブ/レシーブ起点の連鎖を1得点=1レコードで記録、専用の分析ページで集計表示する。

---

## 設計判断（論点への回答）

### 論点2: MatchInfo の扱い → 既存 MatchInfo に相乗り（推奨）
別モデル化せず、`MatchInfo` に `analysis_type` enum（`technique`=既存 / `serve_receive`=新機能）を追加する。

理由:
- 試合情報(日付/大会名/選手名)・autocomplete・`find_or_create_players`・ドラフト機構(draft/partial_game_data)・`scoreboard` partial を**そのまま流用**でき、新規作成コードを最小化できる。別モデルにすると Player belongs_to / ransack / autocomplete / pagy を二重実装することになる。
- `index` は `analysis_type` で表示カードを出し分け（あるいは両方表示しリンク先を分岐）。`show`/`new`/`create`/`end_game`/`interrupt` は `analysis_type` で分岐。
- 既存試合入力フローには一切手を入れない方針なので、`analysis_type` のデフォルトは `technique`（既存データは全て technique 扱い、後方互換）。

代替案（別モデル ServeReceiveMatch）は選手・autocomplete・index/show の重複コストが大きく不採用。

### 論点1: データモデル → 新テーブル `serve_receive_patterns`、回転は **integer配列(array: true)**
回転の複数選択の持ち方の判断:
- 中間テーブル: 既存にその流儀がなく過剰。不採用。
- jsonb: 既存 `partial_game_data` で jsonb 実績はあるが、集計で配列要素ごとの GROUP/フィルタをやりたいので不向き。
- **integer配列 (`t.integer :serve_spins, array: true, default: []`)**: PostgreSQL ネイティブ。Rails で `enum` 化はできないが、定数マップ＋スコープで扱える。回転は「下回転/上回転/ナックル/順横回転/逆横回転」の固定5種で、集計時に `unnest`/Ruby側 flatten が容易。**これを採用**。
  - 補足: 既存 array 列は無いが、Rails標準機能であり流儀違反ではない。`spin` 自体は batting_style とは別概念（enum重複を避ける）なので独自定数で定義。

### 論点の内部表現
- `origin`: enum `{ serve: 0, receive: 1 }`（その得点が自分のサーブ番かレシーブ番か。`RallyContextBuilder#my_serve?` で自動判定）
- `serve_length`: enum `{ long: 0, half_long: 1, short: 2 }`（nullable, origin=serve時のみ）
- `serve_spins`: integer配列（origin=serve時のみ。定数 `SERVE_SPINS = { backspin:0, topspin:1, no_spin:2, pro_sidespin:3, anti_sidespin:4 }`）
- `receive_style`: integer（batting_style enum 値, nullable, origin=receive時のみ。レシーブの種類）
- `attack_style`: integer（batting_style enum 値。serve起点=3球目 / receive起点=4球目の技術）
- `decided_at`: enum `{ attack_ball: 0, follow_ball: 1, rally: 2 }`（3or4球目 / 5or6球目 / サーブ起点:7球目以降/レシーブ起点:8球目以降）
- `won`: boolean（自分が得点なら true）
- 結果6種は `decided_at × won` で表現。得点板は won=true→自分+1, won=false→相手+1。

---

## 1. データモデル / マイグレーション

新規migration（schema版 `2026_05_18_052507` より後のタイムスタンプ。例 `20260518060000` 系）。`ActiveRecord::Migration[7.1]` 準拠、`t.references ..., foreign_key: true` + `t.timestamps`、複合index は create_table 外で add_index（`create_rallies.rb` の流儀）。

### migration A: AddAnalysisTypeToMatchInfos
```
add_column :match_infos, :analysis_type, :integer, null: false, default: 0
```
（0=technique。既存データは自動で technique）

### migration B: CreateServeReceivePatterns
```
create_table :serve_receive_patterns do |t|
  t.references :match_info, null: false, foreign_key: true
  t.references :game, null: true, foreign_key: true
  t.integer :game_number, null: false
  t.integer :sequence_number, null: false
  t.integer :origin, null: false
  t.integer :serve_length            # nullable
  t.integer :serve_spins, array: true, default: []
  t.integer :receive_style           # nullable (batting_style値)
  t.integer :attack_style, null: false # batting_style値（3or4球目）
  t.integer :decided_at, null: false
  t.boolean :won, null: false
  t.timestamps
end
add_index :serve_receive_patterns, [:match_info_id, :game_number, :sequence_number],
          unique: true, name: 'index_srp_on_match_info_game_sequence'
```

---

## 2. モデル

### app/models/match_info.rb（編集・流用）
- `enum :analysis_type, { technique: 0, serve_receive: 1 }` を追加。
- `has_many :serve_receive_patterns, dependent: :destroy` を追加。
- 既存メソッドは無変更。`index`/`show` 分岐用に `serve_receive?` を enum が提供。

### app/models/serve_receive_pattern.rb（新規）
- `belongs_to :match_info` / `belongs_to :game, optional: true`
- `enum :origin, { serve: 0, receive: 1 }`
- `enum :serve_length, { long: 0, half_long: 1, short: 2 }`
- `enum :decided_at, { attack_ball: 0, follow_ball: 1, rally: 2 }`
- `enum :attack_style` / `enum :receive_style`: **batting_style と同じ整数マップを共有**。`Score::BATTING_STYLES` のような共通定義を使いたいが、既存は Score/Rally で enum をベタ書き重複している流儀。→ 流儀に合わせ、同じ enum ハッシュを `attack_style`/`receive_style` で再掲（serve/receive含む全マップ、ただし入力UI/集計で `serve` `receive` を除外）。
- 定数 `SERVE_SPINS = { backspin: 0, topspin: 1, no_spin: 2, pro_sidespin: 3, anti_sidespin: 4 }` と日本語マップ。
- `validates :origin, :attack_style, :decided_at, :game_number, :sequence_number, presence: true`（won は boolean なので presence 不要、`inclusion: [true,false]`）。
- `self.allowed_attack_styles` = batting_styles.keys - %w[serve receive]（入力候補20種）。

I18n: `config/locales/ja.yml` に `serve_receive_pattern` の `origin`/`serve_length`/`decided_at`/`serve_spin` の和名を追加。`attack_style`/`receive_style` の和名は既存 `Score.human_enum_name(:batting_style, ...)` を流用（新規作成しない）。

---

## 3. ルーティング

`config/routes.rb` の `resources :match_infos` collection を流用しつつ、新フロー専用アクションを追加。MatchInfo相乗りなので**新リソースは作らない**。

```
resources :match_infos do
  collection do
    get :autocomplete            # 流用（field分岐済み）
    post :end_game
    delete :undo_game
    post :interrupt
    post :restore_autosave
    # 新機能
    get  :new_serve_receive      # 新フロー入口（index ボタンから）
    post :create_serve_receive
    post :end_game_serve_receive
  end
end
```
（最小化のため `analysis_type=serve_receive` を `new`/`create`/`end_game` 内分岐にする案も可。本plan は新アクションで明示分離する方が既存 technique フローへの影響ゼロで安全と判断。show は同一 `show` を analysis_type で分岐。）

---

## 4. コントローラ

`app/controllers/match_infos_controller.rb` に新アクションを追加（既存 private メソッドの **流用** が中心。`find_or_create_players` / `draft_or_new_match_info` / `basic_match_info_params` / `autocomplete` はそのまま）。

- `new_serve_receive`: `setup_new_form` 流用 + `@match_info.analysis_type = :serve_receive`。draft_id 対応も `setup_draft_form` 流用。
- `create_serve_receive`: `create` を踏襲。`draft_or_new_match_info` で MatchInfo を作り `analysis_type: :serve_receive` を付与、保存後 `create_game_from_patterns` を呼ぶ。
- `end_game_serve_receive`: 既存 `end_game`→`persist_and_finalize_game` の構造を踏襲し、`create_game_from_patterns` 版を用意。
- `show`: 既存に `if @match_info.serve_receive?` 分岐を追加し、`@srp_analysis = ServeReceiveAnalyzer.new(@match_info)` をセット（ChatgptService呼び出しはスキップ or 別扱い）。

新規 private（`create_game_from_rallies` 系の鏡像）:
- `create_game_from_patterns(match_info)`: `params[:patterns]`(JSON) を parse。
- `create_game_record_from_patterns`: won true/false 集計で `player_score`/`opponent_score`/`first_server` を持つ Game を作る（`create_game_record_from_rallies` と同型）。`first_server` は `params[:first_server]` を流用。
- `persist_pattern_records`: each_with_index で `match_info.serve_receive_patterns.create!(...)`。
- `pattern_params`: `JSON.parse(params[:patterns])`。

`my_serve?` ロジックは **JS側で算出した origin を信頼**しつつ、サーバ側でも `RallyContextBuilder#my_serve?` を切り出した共有メソッドで検証/再計算できるようにする（DRYのため `RallyContextBuilder.my_serve?(first_server, sequence_number)` をクラスメソッド化 or ServiceObjectに抽出。最小変更なら既存private を残しつつ新Analyzerに同ロジックをコピーしない方針で共有モジュール `ServeOrderCalculator` を新設）。

---

## 5. View

`app/views/match_infos/` 配下に追加（既存 partial を最大流用）。

- `new_serve_receive.html.erb`（新規, `new.html.erb` の鏡像）: `_serve_receive_form` を render。
- `_serve_receive_form.html.erb`（新規, `_form.html.erb` を土台に複製改変）:
  - 試合情報フィールド(date/match_name/match_format/player_name/opponent_name/memo) と autocomplete・`scoreboard` data 属性は **そのままコピー**。
  - `form_with url: create_serve_receive_match_infos_path`。
  - `render 'match_infos/scoreboard'` を**流用**（無変更）。
  - `render 'match_infos/serve_receive_input'`（新規 partial）。
  - hidden `name="patterns"`（rally_input の serialized 相当）, `name="first_server"`。
  - submit: 「Nゲーム目終了」→ `end_game_serve_receive_match_infos_path`、「試合を分析する」→ `create_serve_receive`。`interrupt`/autosave は流用 or Sprintで後追い。
- `_serve_receive_input.html.erb`（新規, `_rally_input.html.erb` を土台）:
  - サーブ権選択エリア（`_rally_input` の server-select 流用）→ origin 自動判定表示。
  - origin=serve: サーブ長さ(3ボタン択一) → 回転(5ボタン複数選択トグル) → 3球目技術ボタン群 → 結果6ボタン。
  - origin=receive: レシーブ技術ボタン群 → 4球目技術ボタン群 → 結果6ボタン。
  - 入力済み一覧。
- show 側: `_serve_receive_analysis.html.erb`（新規）で `_batting_score_table` を **theme: :player/:opponent で流用**して各集計テーブルを表示。show.html.erb に `if @match_info.serve_receive?` 分岐追加。
- index 側: `index.html.erb` に「サーブ・レシーブ分析を開始」ボタン追加（`new_serve_receive_match_infos_path`）。`_match_info_summary` を analysis_type バッジ表示に微修正、リンク先は show 共通。

---

## 6. Stimulus

`app/javascript/controllers/serve_receive_input_controller.js`（新規, `rally_input_controller.js` を土台に状態機械を拡張）。

- 定数: `BATTING_STYLE_NAMES`（既存からコピー）, `SERVE_LENGTHS`, `SERVE_SPINS`, `DECIDED_RESULTS`(6種ラベル)。
- 状態: `this.patterns=[]`, `this.firstServer`, ステップ管理（`origin → (serveLength→spins[] | receiveStyle) → attackStyle → result`）。
- origin 自動判定: 既存 `getCurrentServer()` を**そのまま流用**（first_server + patterns.length から算出 → player なら serve, opponent なら receive）。
- 回転は複数選択: spinボタンを toggle、選択配列を保持、「次へ」で確定。
- 結果6ボタン押下で1 pattern を push、`{origin, serve_length, serve_spins, receive_style, attack_style, decided_at, won}` を構築。won で得点板加算（`rally:scoreUpdated` イベント発火、`scoreboard_controller` を**無変更で流用**）。
- `serializePatterns()` → hidden `patterns` にJSON。`firstServerField` 連携も流用。
- undo/showMore/サーバーインジケータは `rally_input_controller` から流用。

---

## 7. 集計（サービス層）+ ヘルパー

集計はサービス、表示は partial の分離（`RallyContextBuilder` + `_batting_score_table` の流儀）。

`app/services/serve_receive_analyzer.rb`（新規）:
- `initialize(match_info)` で `match_info.serve_receive_patterns` をロード。
- 集計メソッド（`_batting_score_table` が期待する `{ batting_style:, score:, lost_score:, share: }` 形に整形）:
  - `serve_length_stats`（サーブ別 得点/失点）
  - `serve_pattern_stats`（サーブ長さ＋回転＋3球目 の組合せ別）
  - `receive_style_stats`（レシーブ別）
  - `receive_pattern_stats`（レシーブ＋4球目 の組合せ別）
  - `decided_at_distribution`（決着タイミング分布）
- `append_share`/share% は `ApplicationHelper` に既にある（`build_aggregated_score_data`/`append_share`）。**集計結果を helper互換ハッシュに合わせれば `_batting_score_table` をそのまま使える**。組合せ別パターンは batting_style キー単独でないため、テーブル表示用に「ラベル文字列」列を持つ簡易 partial を1枚追加するか、`_batting_score_table` の `Score.human_enum_name` 部分をラベル直挿しできるよう小改修。

---

## 8. テスト方針（各Sprintで rspec + rubocop 緑）

- `spec/factories/serve_receive_patterns.rb`（新規, `rallies.rb` factory に倣う）。
- `spec/models/serve_receive_pattern_spec.rb`: enum/validation/`allowed_attack_styles`/spins配列。
- `spec/models/match_info_spec.rb`（追記）: analysis_type enum, 関連。
- `spec/services/serve_receive_analyzer_spec.rb`: 各集計の数値・share%・空データ。
- `spec/requests/match_infos_spec.rb`（追記）: `new_serve_receive`/`create_serve_receive`/`end_game_serve_receive` の POST、patterns JSON 永続化、得点集計、認可(`current_user.match_infos`)。
- `spec/system/...`（任意）: 入力フロー（origin→結果6ボタン→保存）。
- rubocop: `RallyContextBuilder` 同様 `# rubocop:disable Metrics/...` を必要箇所に。

---

## 9. スプリント分割（feature/sprint-N-xxx）

既存リポジトリの `feature/sprint-N-xxx` ＋ PRマージ運用に合わせる。各Sprint末で rspec/rubocop 緑。

### Sprint 1 — feature/sprint-1-serve-receive-model
- migration A/B（analysis_type, serve_receive_patterns）。
- `ServeReceivePattern` モデル + `MatchInfo` enum/関連 + I18n。
- factory + model spec。
- 入力UI/集計はまだ。`db:migrate` + green。
- 成果物: スキーマとモデルが揃い、コンソール/specでレコード作成可能。

### Sprint 2 — feature/sprint-2-serve-receive-input
- ルーティング(new/create/end_game_serve_receive)。
- コントローラ新アクション + `create_game_from_patterns` 系 private。
- `new_serve_receive`/`_serve_receive_form`/`_serve_receive_input` View。
- `serve_receive_input_controller.js`（origin自動判定・サーブ長さ・回転複数選択・攻撃技術・結果6ボタン・得点板連携）。
- index に開始ボタン。
- request spec（保存・集計・認可）。
- 成果物: 入口→入力→保存→（暫定の素朴な show 表示 or リダイレクト）まで通る。

### Sprint 3 — feature/sprint-3-serve-receive-analysis
- `ServeReceiveAnalyzer` サービス + spec。
- show 分岐 + `_serve_receive_analysis` partial（`_batting_score_table` 流用＋パターン用ラベル表示）。
- 5種集計（サーブ別/サーブ→3球目/レシーブ別/レシーブ→4球目/決着タイミング）。
- 成果物: 専用分析ページ完成。

### Sprint 4（任意・余力）— feature/sprint-4-serve-receive-ux
- interrupt/undo_game/auto_save の新フロー対応（既存機構流用）。
- index カードの analysis_type バッジ整備、show の AI連携要否判断。
- system spec 拡充。

---

## 再利用（新規作成しない）一覧
- `scoreboard` partial / `scoreboard_controller.js`: 無変更で流用。
- `auto_save_controller.js`: 流用（Sprint4でフィールド名対応のみ）。
- `find_or_create_players` / `draft_or_new_match_info` / `basic_match_info_params` / `autocomplete` / `autocomplete_candidates`: 流用。
- `_batting_score_table.html.erb`（theme: :player/:opponent, 構成比バー）: 流用。
- `ApplicationHelper`の `append_share` / `build_aggregated_score_data` / `abbreviate_batting_style`: 流用。
- `Score.human_enum_name(:batting_style, ...)`: 攻撃技術/レシーブ技術の和名に流用（新I18nキー作らない）。
- `RallyContextBuilder#my_serve?` のロジック: origin自動判定に流用（共有メソッド化）。
- 入力UIの型（form_with + Stimulus + hidden JSON, 段階UI, server選択）: `_form`/`_rally_input`/`rally_input_controller.js` を土台に複製改変。

## 新規作成
- migration ×2 / `ServeReceivePattern` モデル / `ServeReceiveAnalyzer` サービス /
  controller 新アクション群 / `new_serve_receive`・`_serve_receive_form`・`_serve_receive_input`・`_serve_receive_analysis` view /
  `serve_receive_input_controller.js` / 各 spec / factory / ja.yml 追記 / routes 追記。
