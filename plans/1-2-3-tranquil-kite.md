# Phase 1: 対戦相手タイプ ＋ タイプ別分析

## Context（なぜこの実装をするのか）

T.T.LOGのロードマップ（`plans/77-phase-0-77-1-replicated-twilight.md`）における次フェーズ。Phase 0（複数試合横断の成長ダッシュボード）はSprint 1〜3までmainにマージ済み・修正スプリント3件（下書き除外／用語変更／期間別テーブル追加）も完了済み。

ロードマップ上のPhase 1の狙いは「強い差別化ポイント」であり、#77（サーブ・レシーブパターン分析）と掛け合わせて「カットマン相手の3球目決定率」のような分析を可能にすること。試合登録時に対戦相手のタイプを記録し、複数試合を横断してタイプ別の勝率・技術傾向を見られるようにする。

### ユーザー承認済みの設計方針

1. **保存先はMatchInfo（Playerではない）**。`find_or_create_players`（`match_infos_controller.rb`）が`Player.find_or_create_by(player_name:)`で同名の対戦相手を同じPlayerレコードとして再利用する既存設計のため、タイプをPlayerに持たせると「一人に1つのタイプ」が一貫する一方、後から変更すると過去の試合もまとめて分類が変わってしまう。試合ごとに独立させ、後から変更しても過去データに影響しない設計とする。
2. **「利き手」「ラケット」「ラバー」「戦型」の4つの独立した属性に分ける**。いずれも**任意入力（未設定可）**。既存試合には値がないため後方互換が必須。
3. **（2026-10-23改訂）項目の定義・並び順・表示形式をユーザーレビューで確定**：
   - 「戦法」→「**戦型**」に名称変更
   - 「グリップ」→「**ラケット**」に名称変更
   - 新規属性「**ラバー**」を追加（フォア／バックの2軸）
   - フォーム上の表示順は **利き手 → ラケット → ラバー → 戦型**
   - 「利き手」は右利き／左利きの2値のまま、ラベルから「（サウスポー）」の表記を削除
   - 「戦型」の選択肢は前陣ドライブ型／中陣ドライブ型／前陣ミート型／ブロック型／カットマン／その他（自由入力）
   - タイプ別勝率・タイプ別決定率の表示は**数値テーブルのみ**（既存の得点構成比グラフとは別物として、折れ線グラフ化はしない）

---

## データモデル設計

### Migration（1本、`AddOpponentAttributesToMatchInfos`）

```ruby
add_column :match_infos, :opponent_handedness, :integer
add_column :match_infos, :opponent_racket, :integer
add_column :match_infos, :opponent_rubber_forehand, :integer
add_column :match_infos, :opponent_rubber_backhand, :integer
add_column :match_infos, :opponent_playstyle, :integer
add_column :match_infos, :opponent_playstyle_other, :string
```
全て`null: true`・デフォルト値なし（未設定可）。indexは不要（Phase 0の`GrowthDashboardAggregator`同様メモリ集計で足りる規模）。

### `app/models/match_info.rb`

```ruby
enum :opponent_handedness, { right: 0, left: 1 }, prefix: :opponent_handedness
enum :opponent_racket, { shakehand: 0, penholder: 1 }, prefix: :opponent_racket
enum :opponent_rubber_forehand, { backside: 0, pips_out: 1, pips_long: 2, anti: 3 }, prefix: :opponent_rubber_forehand
enum :opponent_rubber_backhand, { backside: 0, pips_out: 1, pips_long: 2, anti: 3, none: 4 }, prefix: :opponent_rubber_backhand
enum :opponent_playstyle, { front_drive: 0, mid_drive: 1, front_hit: 2, blocker: 3, cutman: 4, other: 5 }, prefix: :opponent_playstyle
```
`prefix:`は`ServeReceivePattern#origin`の既存流儀（`prefix: :origin`）に揃え、生成スコープ名の衝突を避ける。

`opponent_playstyle_other`は`opponent_playstyle`が`other`のときだけ意味を持つ自由入力の文字列。`other`以外を選んでいる場合に値が残っていても集計上は無視する（厳密なクリア処理は不要、完全に任意項目のため）。

`Score.human_enum_name`相当のクラスメソッドが`MatchInfo`には無いため、同じ実装を追加：
```ruby
def self.human_enum_name(enum_name, key)
  I18n.t("activerecord.attributes.match_info.#{enum_name}.#{key}")
end
```

試合単位の勝敗判定（`game_count_score`のゲーム単位ロジックを転用、タイプ別勝率で使用）：
```ruby
def result
  return nil if games.none?
  player_wins = games.count { |g| g.player_score > g.opponent_score }
  opponent_wins = games.count { |g| g.player_score < g.opponent_score }
  return nil if player_wins == opponent_wins
  player_wins > opponent_wins ? :win : :lose
end
```

### `config/locales/ja.yml`
`activerecord.attributes.match_info`配下に5つのenumの和名キーを追加：
- `opponent_handedness`: `right: 右利き` / `left: 左利き`
- `opponent_racket`: `shakehand: シェークハンド` / `penholder: ペンホルダー`
- `opponent_rubber_forehand`: `backside: 裏ソフト` / `pips_out: 表ソフト` / `pips_long: 粒高` / `anti: アンチ`
- `opponent_rubber_backhand`: 上記4つ + `none: なし`
- `opponent_playstyle`: `front_drive: 前陣ドライブ型` / `mid_drive: 中陣ドライブ型` / `front_hit: 前陣ミート型` / `blocker: ブロック型` / `cutman: カットマン` / `other: その他`

属性ラベル自体（フォームの`label`）も追加：`opponent_handedness: "利き手"` / `opponent_racket: "ラケット"` / `opponent_rubber_forehand: "ラバー（フォア）"` / `opponent_rubber_backhand: "ラバー（バック）"` / `opponent_playstyle: "戦型"` / `opponent_playstyle_other: "戦型（その他・自由入力）"`

### Factory
`spec/factories/match_infos.rb`はデフォルトで5属性を設定しない（未設定ケースのテストを容易にするため）。タイプ別分析spec用に`trait`（例: `:vs_cutman`）を必要に応じて追加。

---

## 既存試合登録フローへの統合

対戦相手タイプは「試合情報セクション」に属する軽量な属性であり、#77の「完全独立フロー」方針（入力UI・JS・保存ロジックの複雑さを分離する目的）とは別軸。**通常フロー・#77フローの両方に追加する**（カットマン相手の3球目決定率分析には#77データとの掛け合わせが必須のため）。

確認済みの事実：
- `app/views/match_infos/_form.html.erb`（通常フロー）と`_serve_receive_form.html.erb`（#77フロー）は、どちらも「選手名/対戦相手名」の`row`（47-63行目付近）が同一構造。
- 編集画面は`_form_edit.html.erb`（`_form.html.erb`とは別ファイル）。
- パラメータ許可は`match_infos_controller.rb`の`basic_match_info_params`（241行目付近、`create`/`end_game`/`create_serve_receive`/`end_game_serve_receive`全アクション共通の`draft_or_new_match_info`から呼ばれる）と`match_info_params`（549行目、`update`用）の2箇所。

### 変更内容
1. 新規partial `app/views/match_infos/_opponent_attributes_fields.html.erb`（`form`をローカル変数で受け取り、**利き手 → ラケット → ラバー（フォア/バック） → 戦型**の順に`select`を表示。`include_blank: "未設定"`）。
   - 戦型で「その他」を選んだ場合のみ自由入力テキスト欄を表示する必要があるため、新規Stimulus controller `other_text_toggle_controller.js`を追加（`select`の`change`イベントで対象テキスト欄の表示/非表示を切り替える汎用controller）。
2. `_form.html.erb`・`_serve_receive_form.html.erb`・`_form_edit.html.erb`の「対戦相手名」行の直後に`render 'match_infos/opponent_attributes_fields', form: form`を追加
3. `match_infos_controller.rb`の`basic_match_info_params`と`match_info_params`に`:opponent_handedness, :opponent_racket, :opponent_rubber_forehand, :opponent_rubber_backhand, :opponent_playstyle, :opponent_playstyle_other`を追加

ドラフト再開時（`setup_draft_form`）は、ActiveRecordの`form.select`が自動的に既存値を選択状態にするため追加コード不要（「その他」テキスト欄の初期表示だけは、Stimulus controller側で初期値が`other`の場合に表示する分岐が必要）。

---

## タイプ別分析の実装方針

### 1. タイプ別の技術別得点構成比（既存`growth_dashboards`に統合）

`GrowthDashboardAggregator`自体は変更不要。`GrowthDashboardsController#index`で、`current_user.match_infos.completed`に対し`params[:opponent_playstyle]`が存在する場合だけ`where`で絞り込む（存在しない場合は全件、後方互換）。UIは既存の技術選択・期間選択と同じ`select_tag` + `onchange: "this.form.requestSubmit()"`パターンで「戦型」フィルタを1つ追加する。表示はこれまでと同じ折れ線グラフ＋期間別明細テーブル。

利き手／ラケット／ラバーは登録データとしては保持するが、Phase 1ではダッシュボードの絞り込み軸としては追加しない（差別化の中心は戦型＝対戦相手タイプのため）。ただしコントローラ側の絞り込みロジックは属性名をキーにした汎用的な書き方にしておき、将来的に他の属性でも同じ仕組みで絞り込みを追加できるようにする。

### 2. タイプ別勝率（新規サービス）

新規 `app/services/opponent_type_win_rate_aggregator.rb`。`match_infos:`と`attribute:`（`:opponent_playstyle`）を受け取り、`MatchInfo#result`（上記で追加）を使ってタイプごとの勝率を算出する。`GrowthDashboardAggregator#calculate_share`と同じ「件数を数えて割合を出す」パターンを踏襲。表示は`growth_dashboards/index.html.erb`に**数値テーブルのみ**の別セクションとして追加（戦型ごとに試合数・勝数・敗数・勝率%を並べた表）。Phase 1時点では全期間を対象にした単一の集計値のみを表示する（期間別の推移は見せない）。

**将来の拡張可能性（2026-10-23確認）**: このアグリゲーターは「渡された`match_infos`集合を集計するだけ」の設計にするため、後で月別/週別の勝率・決定率の推移テーブルが必要になった場合も、スキーマ変更は不要。`MatchInfo#match_date`を使って`GrowthDashboardAggregator`と同じ期間分割ロジックで`match_infos`を月/週ごとにグルーピングしてから同じアグリゲーターに渡し、期間ごとの行を並べるビューを追加するだけで対応できる（`#77`との掛け合わせである決定率も同様）。Phase 1のスコープには含めない。

### 3. #77との掛け合わせ（カットマン相手の3球目決定率）

`ServeReceiveAnalyzer`は現在`initialize(match_info)`で単一試合の`serve_receive_patterns`を前提にした設計。複数試合をタイプで絞り込んで渡せるようにするため、**`patterns:`キーワード引数も受け付けるよう`initialize`を拡張**し、既存の`match_info:`呼び出し（`MatchInfosController#show`）は無変更で動作することを確認する。

表示先は`MatchInfosController#show`（単一試合の詳細）ではなく、**新規ページ**とする（「カットマン相手全体」は複数試合を跨るため、単一試合に紐づく`show`に置くのは責務的に不自然）。新規コントローラ`OpponentTypeAnalysesController#show`・ルーティング`resource :opponent_type_analysis, only: [:show]`・ビューで、戦型選択に応じて①得点構成比（グラフ＋テーブル）②勝率（数値テーブル）③#77決定率（`analysis_type: :serve_receive`の試合のみ対象、数値テーブル）を1ページにまとめて表示する。

---

## スプリント分割

CLAUDE.mdルール準拠（スプリントごとにブランチ・PR、各スプリント末で`bundle exec rspec && bundle exec rubocop --parallel`緑、RuboCop最大行長120文字・メソッド長20行・クラス長200行、PR作成はユーザー指示があるまで行わない、複数スプリントをまとめない）。

### Sprint 1 — データ基盤（`feature/sprint-1-opponent-attributes-model`）
- Migration（6カラム）、`match_info.rb`への5 enum・`human_enum_name`・`result`メソッド追加
- `ja.yml`への和名・属性ラベル追加、factory trait追加
- model spec: 各enum値、`human_enum_name`、`result`（勝ち/負け/引き分け=nil/試合数0=nil）、`opponent_playstyle_other`が任意の文字列として保存できること
- Sprint末に`bundle exec rspec`全体を通し、既存specへの影響がないか確認（新カラムはnullable・デフォルトなしのため既存factory/specは無傷の見込み）

### Sprint 2 — 試合登録フォームへの統合（`feature/sprint-2-opponent-attributes-form`）
- `_opponent_attributes_fields.html.erb`新規（利き手→ラケット→ラバー→戦型の順）、3フォームへの組み込み
- `other_text_toggle_controller.js`新規（戦型が「その他」のときだけ自由入力欄を表示）
- `basic_match_info_params`・`match_info_params`への6カラム追加
- request spec: 全属性ありでの`create`/`update`/`end_game`/`create_serve_receive`、未設定（空）でも保存できること、戦型が`other`以外のときに`opponent_playstyle_other`があっても保存できること（クリア処理なし）の確認
- system spec: フォームでselect選択→保存→値が保持されること、「その他」選択時にテキスト欄が表示されることの確認

### Sprint 3 — タイプ別技術分析・タイプ別勝率（`feature/sprint-3-opponent-type-dashboard`）
- `opponent_type_win_rate_aggregator.rb`新規
- `growth_dashboards_controller.rb`: 戦型フィルタ・勝率集計の呼び出し追加
- `growth_dashboards/index.html.erb`: 戦型フィルタselect・勝率テーブルセクション追加
- service spec、既存`growth_dashboards`のrequest/system spec拡張（フィルタなし時に全件を返す後方互換を確認）
- **実装時の判断（2026-10-24）**: 戦型別勝率テーブルは「戦型ごとの内訳」を一覧で見せることが目的のため、
  技術別グラフ側の戦型フィルタ（`opponent_playstyle`パラメータ）の影響を受けず、常に全戦型・全期間を対象に
  集計する（フィルタで絞り込むと自分自身1行だけになり意味がなくなるため）。将来的な期間別推移テーブルへの
  拡張可能性は仕様通りアグリゲーター設計で担保済み。

### Sprint 4 — #77との掛け合わせ（`feature/sprint-4-opponent-type-serve-receive`）
- `serve_receive_analyzer.rb`: `patterns:`キーワード引数対応への拡張（既存呼び出し元が無変更で動作することをspecで確認）
- 新規`OpponentTypeAnalysesController#show`・ルーティング・ビュー（対戦成績サマリー／#77決定率テーブル群の2セクション＋成長ダッシュボードへの導線）
- 既存`match_infos/_serve_receive_analysis.html.erb`から表部分を共有partialへ抽出
- ヘッダーナビへの導線追加
- request/system spec新規、`ServeReceiveAnalyzer`・`MatchInfosController#show`既存specの後方互換確認

#### 詳細設計（2026-10-26 確定・着手前レビュー結果）

Sprint 1〜3の実装を確認した上で、プラン策定時に「要判断」としていた論点に以下の結論を出す。
この節は「タイプ別分析の実装方針」3.（117〜121行目）を具体化するものであり、齟齬がある場合はこの節を優先する。

**(a) `ServeReceiveAnalyzer`は新規クラスを作らず既存クラスを拡張する**

現状の呼び出しは`ServeReceiveAnalyzer.new(@match_info)`（`MatchInfosController#show`）と
`ServeReceiveAnalyzer.new(match_info)`（`ServeReceiveContextBuilder#initialize`）の2箇所で、
いずれも**位置引数**（プラン本文の「既存の`match_info:`呼び出し」という記述は実装と異なっていた）。
集計ロジック（`serve_length_stats`等）は`@patterns`の中身にしか依存せず、複数試合分のパターンを
渡しても意味のある集計になるため、別クラスを立てるとロジックが丸ごと重複する。したがって：

```ruby
def initialize(match_info = nil, patterns: nil)
  raise ArgumentError, "match_info または patterns のいずれかが必要です" if match_info.nil? && patterns.nil?

  @patterns = (patterns || match_info.serve_receive_patterns).to_a
  @serve_patterns   = @patterns.select(&:origin_serve?)
  @receive_patterns = @patterns.select(&:origin_receive?)
end
```

位置引数は任意化するのみで、既存2箇所の呼び出し元・既存specは**無変更**。
他のpublic/privateメソッドにも変更は入らない。

**(b) 新規ページは単数リソースのコントローラ1本＋専用ビューとする**

- ルーティング: `resource :opponent_type_analysis, only: [:show]`（`resources :growth_dashboards`の直後に追加）。
  単数形リソースとし、URLは`/opponent_type_analysis?opponent_playstyle=cutman`、コントローラは
  `OpponentTypeAnalysesController`。戦型はパスではなくクエリパラメータで受けることで、Sprint 3で採用した
  「`select_tag` + `onchange: "this.form.requestSubmit()"`」のフィルタUIパターンをそのまま流用できる。
- 選択戦型の決定: `params[:opponent_playstyle]`が`MatchInfo.opponent_playstyles`のキーに一致する場合のみ採用。
  未指定・不正値の場合は**完了試合数が最も多い戦型**にフォールバックする（同数の場合はenum定義順の先頭、
  該当データが0件の場合は`front_drive`）。初回アクセスで空ページを見せないための決定論的なデフォルト。
- 対象試合の絞り込み: 戦型が1つに確定しているため、Sprint 3の`OPPONENT_ATTRIBUTE_FILTERS`ハッシュのような
  汎用フィルタ機構は**導入しない**（絞り込み軸が1つしかない段階での早すぎる抽象化を避ける）。
  許可値チェックの3行は`GrowthDashboardsController#resolve_opponent_playstyle`と同等のものを
  新コントローラにも置き、共通化は3箇所目が出てきた時点で検討する。
- 集計対象:
  - 対戦成績サマリー: `current_user.match_infos.completed.includes(:games)`（`analysis_type`は問わない）
  - 決定率: 上記に加えて`.where(analysis_type: :serve_receive, opponent_playstyle: @opponent_playstyle)`で
    絞った試合IDに対し、`ServeReceivePattern.where(match_info_id: ids).order(:game_number, :sequence_number)`で
    1クエリまとめて取得し、`ServeReceiveAnalyzer.new(patterns: patterns)`へ渡す（N+1回避）。

**(c) 勝率は`OpponentTypeWinRateAggregator`を再利用し、新規サービスは作らない**

Sprint 3で実装済みの`OpponentTypeWinRateAggregator.new(match_infos:, attribute: :opponent_playstyle)`は
「渡された集合を集計するだけ」の設計になっているため、全戦型の集計結果から選択戦型の行を
`find`で取り出すだけでサマリーが作れる。決定率側の新規サービスも不要（(a)の`ServeReceiveAnalyzer`で足りる）。
**Sprint 4で新規追加するサービスクラスは無し**とする。

**(d) 得点構成比セクションは新規ページに持たず、成長ダッシュボードへのリンクで代替する**

プラン本文121行目では新規ページに「①得点構成比（グラフ＋テーブル）」を含める想定だったが、
Sprint 3で`/growth_dashboards`に戦型フィルタを実装済みであり、同じグラフ＋期間別テーブルを
新規ページに再実装すると技術セレクト・期間セレクトごと重複する。したがって新規ページの構成は：

1. 戦型セレクト（ページ共通フィルタ）
2. 「この戦型との対戦成績」— 試合数／勝数／敗数／勝率の数値表示
3. 「サーブ・レシーブ分析（3球目・4球目）」— サーブ長さ別／サーブ→3球目／レシーブエース・ミス／
   レシーブ→4球目／得点タイミング分布の5表
4. 「この戦型の得点構成比の推移を見る」→ `growth_dashboards_path(opponent_playstyle: @opponent_playstyle)`へのリンク

とし、得点構成比は既存ダッシュボードに戦型を引き継いで遷移させる形で担保する。

**(e) 表の描画は既存partialから共有partialを抽出して再利用する**

`match_infos/_serve_receive_analysis.html.erb`は5つの表に加えて単一試合向けの空状態
（「サーブ・レシーブ分析を始める」ボタン）を含むため、そのままでは流用できない。
表部分（3セクション分のカード）を`app/views/match_infos/_serve_receive_stats_sections.html.erb`として
抽出し、`srp_analysis`をローカル変数で受け取る形にする。空状態の文言は呼び出し側それぞれが持つ：

- 既存`_serve_receive_analysis.html.erb`: 現状の文言・ボタンを維持（表示結果は変わらないこと）
- 新規`opponent_type_analyses/show.html.erb`: 「この戦型のサーブ・レシーブ分析データがまだありません」＋
  `new_serve_receive_match_infos_path`への導線

表自体は既存`match_infos/_serve_receive_score_table`をそのまま使う（変更なし）。

**(f) 導線**

`app/views/shared/_header.html.erb`の「試合分析」ドロップダウン（PC）とモバイル用`nav-item`の両方に
「対戦相手タイプ別分析」（`NEW`バッジ・補足文「戦型ごとの勝率と3球目パターンを確認」）を
成長ダッシュボードの直後に追加する。

**(g) テスト**

- `spec/services/serve_receive_analyzer_spec.rb`（既存ファイルに追記）: `patterns:`で複数試合のパターンを
  渡すと合算集計されること、位置引数の既存呼び出しが従来通り動くこと、両方未指定で`ArgumentError`
- `spec/requests/opponent_type_analyses_spec.rb`（新規）: 未ログイン時のリダイレクト、デフォルト戦型の決定、
  不正パラメータのフォールバック、他ユーザーの試合が混ざらないこと、下書き（`draft: true`）が除外されること、
  `analysis_type: technique`の試合が決定率セクションに含まれないこと、データ0件時の空状態
- `spec/system/opponent_type_analyses_spec.rb`（新規）: ヘッダーから遷移できること、戦型セレクトを切り替えると
  表示内容が切り替わること
- 後方互換: `spec/requests/match_infos_spec.rb`の`@srp_analysis`期待と既存system specが無修正で通ること

依存関係: Sprint 1は全ての前提。Sprint 2はSprint 1完了後。Sprint 3・4はSprint 2完了後ならどちらでも着手可能だが、Sprint 4はSprint 3のフィルタ実装パターンを再利用できるため3→4の順を推奨。

---

## 検証方法

各スプリント共通: `bundle exec rspec && bundle exec rubocop --parallel`が緑であること。

- **Sprint 2完了後**: `/match_infos/new`・`/match_infos/new_serve_receive`で対戦相手名欄の下に「利き手」「ラケット」「ラバー（フォア/バック）」「戦型」のselectが順番に表示され、戦型で「その他」を選ぶとテキスト欄が出ること、値を設定して保存→`show`/`edit`で保持されることを確認。未設定のまま保存してもエラーにならないことを確認。
- **Sprint 3完了後**: 複数試合（カットマン相手2件、前陣ドライブ型相手1件等）を登録し、`/growth_dashboards`で戦型フィルタを使って得点構成比グラフが絞り込まれること、戦型別勝率テーブルが手計算と一致することを確認。
- **Sprint 4完了後**: `analysis_type: serve_receive`でカットマン相手の試合を複数登録し、`/opponent_type_analysis`で3球目決定率テーブル等が複数試合をまとめて集計されること（手計算と一致すること）、戦型セレクトの切り替えで集計対象が変わること、得点構成比リンクから戦型を引き継いで`/growth_dashboards`へ遷移できること、既存の単一試合`show`ページ（#77の分析表示）が壊れていないことを確認。

### Critical Files
- `app/models/match_info.rb`
- `app/controllers/match_infos_controller.rb`
- `app/services/growth_dashboard_aggregator.rb`
- `app/controllers/growth_dashboards_controller.rb`
- `app/services/serve_receive_analyzer.rb`
- `config/locales/ja.yml`
- `app/views/match_infos/_form.html.erb` / `_serve_receive_form.html.erb` / `_form_edit.html.erb`
- `app/javascript/controllers/other_text_toggle_controller.js`（新規）
- `app/services/opponent_type_win_rate_aggregator.rb`
- `app/controllers/opponent_type_analyses_controller.rb`（Sprint 4で新規）
- `app/views/opponent_type_analyses/show.html.erb`（Sprint 4で新規）
- `app/views/match_infos/_serve_receive_analysis.html.erb` / `_serve_receive_stats_sections.html.erb`（Sprint 4で抽出）
- `app/views/shared/_header.html.erb`
- `config/routes.rb`
