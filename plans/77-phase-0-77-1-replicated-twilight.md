# #77 サーブ・レシーブ起点の3球目/4球目パターン分析 ＋ 今後の実装ロードマップ

## Context（なぜこの実装をするのか）

T.T.LOG は現在「1試合を深く分析する」機能（ラリー単位入力・得点推移表・技術別得点ランキング・文脈リッチなAIアドバイス）が高い完成度にある一方、複数試合をまたいだ成長分析や収益化基盤は未実装である。

今後は「積み上げ型 SaaS（卓球プレイヤーの成長データ基盤）」へ進化させ、最終的にフリーミアム課金（閲覧制限型）で収益化する方針。その第一歩として、卓球経験者に最も刺さる差別化機能 **#77「サーブ・レシーブ起点の3球目/4球目パターン分析」** から着手する。

この機能は既存の「技術別得点率」分析とは**完全に独立した、もう一つの分析機能**。卓球で重要な「サーブからの3球目」「レシーブからの4球目」の連鎖を記録・分析する。
例:「ショート下回転サーブを出して3球目で対下回転フォアドライブを打って得点」。

ユーザー承認済みの設計方針:

- **完全独立フロー** — 既存の試合入力には一切手を入れず、別の入力画面・別の分析として並走させることで「普段の入力は軽いまま、深く分析したい人だけ使う」を実現する（入力負荷の増大を回避）。
- 入力画面には**現在と同じ仕様の試合情報（日付・大会名・選手名 autocomplete）と得点板**を設置する。

---

# Part 1: #77 実装プラン（今すぐ着手）

## 確定仕様

### 入力フロー

- **入口**: 試合分析一覧ページ（`match_infos#index`）に新規ボタンを設置 → 専用入力ページへ。
- **構成**: 試合情報（既存と同じ）＋ 得点板 ＋ サーブ権選択 ＋ 得点ごとのパターン入力。ゲーム単位で進行（ゲーム終了→次ゲーム→試合終了→分析表示）。
- 「自分のサーブ」か「自分のレシーブ」かは `first_server` ＋ 得点順から**自動判定**（既存ロジック流用、後述）。

### 記録内容（1得点 = 1レコード）

- **サーブ起点**: ①サーブの種類（長さ1つ＋回転 複数選択可）②3球目の技術 ③結果
- **レシーブ起点**: ①レシーブの種類 ②4球目の技術 ③結果
- **サーブの長さ**: ロング / ハーフロング / ショート（1つ）
- **サーブの回転**: 下回転 / 上回転 / ナックル / 順横回転 / 逆横回転（**複数選択可**。例「順横回転＋下回転＝順横下回転」）
- **技術（3球目/4球目/レシーブ）**: 既存 `batting_style` enum の **serve を除いた値**。ドライブ系は対◯回転を内包（`fore_drive_vs_backspin` = 対下回転フォアドライブ）。
- **結果（6種類）**: 決着タイミング × 勝敗
  - サーブ起点: 3球目で得点/失点 ・ 5球目で得点/失点 ・ 7球目以降で得点/失点
  - レシーブ起点: 4球目で得点/失点 ・ 6球目で得点/失点 ・ 8球目以降で得点/失点
  - 内部表現: `decided_at`（attack_ball=3or4球目 / follow_ball=5or6球目 / rally=サーブ起点:7球目以降/レシーブ起点:8球目以降）× `won`（boolean）。`won` で得点板を増減。

## データモデル

### MatchInfo に相乗り（別モデルにしない）

`app/models/match_info.rb` に `enum :analysis_type, { technique: 0, serve_receive: 1 }`（default 0）を追加。

- **理由**: 試合情報フィールド・autocomplete・`find_or_create_players`・`draft_or_new_match_info`・ドラフト機構・scoreboard partial をそのまま流用できる。別モデル化すると Player 関連 / ransack / autocomplete / pagy を二重実装するコストが大きい。
- 既存試合は自動で `technique` 扱い（後方互換）。`index` / `show` は `analysis_type` で分岐。

### 新テーブル `serve_receive_patterns`


| カラム             | 型                                 | 備考                                      |
| --------------- | --------------------------------- | --------------------------------------- |
| match_info_id   | references, null: false           | FK                                      |
| game_id         | references, null: true            | FK（rallies の流儀）                         |
| game_number     | integer, null: false              |                                         |
| sequence_number | integer, null: false              | ゲーム内の得点順                                |
| origin          | integer, null: false              | enum: serve / receive                   |
| serve_length    | integer, null: true               | enum: long / half_long / short          |
| serve_spins     | integer, array: true, default: [] | 回転の複数選択（Postgres array）                 |
| receive_style   | integer, null: true               | batting_style 値（レシーブ起点時）                |
| attack_style    | integer, null: true               | batting_style 値（3球目 or 4球目）             |
| decided_at      | integer, null: false              | enum: attack_ball / follow_ball / rally |
| won             | boolean, null: false              | true=自分の得点                              |
| timestamps      |                                   |                                         |


- 複合 unique index: `[match_info_id, game_number, sequence_number]`（create_table 外で `add_index`）。
- **回転の複数選択は integer 配列列**（`t.integer :serve_spins, array: true, default: []`）。中間テーブルは過剰、jsonb は要素別集計に不向き。回転は固定5種で集計が容易。
- 回転・長さは batting_style とは別概念なので、モデルに独自定数で定義（enum 重複を避ける）:
  - `SERVE_LENGTHS = %i[long half_long short]`
  - `SERVE_SPINS = %i[backspin topspin no_spin pro_sidespin reverse_sidespin]`

## 再利用する既存実装（新規作成しない）


| 用途      | 流用元                                                                                                                                                                                                      |
| ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| サーブ自動判定 | `app/services/rally_context_builder.rb` の `my_serve?(game, sequence_number)`（2点交代・デュース対応済み）→ 共有メソッド化して origin 判定に流用                                                                                      |
| 入力UIの型  | `app/views/match_infos/_form.html.erb`（form_with + Stimulus + hidden field JSON送信）、`_rally_input.html.erb`（サーブ権→段階入力UI）                                                                                  |
| 入力JSの型  | `app/javascript/controllers/rally_input_controller.js`（配列を貯めて hidden input に JSON化、技術ボタン動的生成、`getCurrentServer()`）                                                                                       |
| 得点板     | `app/javascript/controllers/scoreboard_controller.js`（`rally:scoreUpdated` イベント受信。**無変更で流用**）                                                                                                            |
| 保存処理の型  | `match_infos_controller.rb` の `create`→`create_game_from_rallies`→`create_game_record_from_rallies`/`persist_rally_records` の鏡像を新設。`find_or_create_players`/`draft_or_new_match_info`/`autocomplete` は流用 |
| 分析表示    | `app/views/match_infos/_batting_score_table.html.erb`（theme: :player(青)/:opponent(赤)、構成比バー）、`app/helpers/application_helper.rb` の `append_share`/`build_aggregated_score_data`                           |
| 技術の和名   | `Score.human_enum_name(:batting_style, ...)`（新 I18n キー不要）                                                                                                                                                |


## スプリント分割（各スプリント末で `bundle exec rspec && bundle exec rubocop --parallel` が緑）

### Sprint 1 — データ基盤（`feature/sprint-1-serve-receive-model`）

- migration ×2: `AddAnalysisTypeToMatchInfos`、`CreateServeReceivePatterns`（schema 版 `2026_05_18_052507` より後のタイムスタンプ）
- `app/models/serve_receive_pattern.rb` 新規（enum・定数・バリデーション・関連）
- `app/models/match_info.rb` に `analysis_type` enum と `has_many :serve_receive_patterns` 追記
- I18n（回転・長さ・決着タイミングの和名）、factory、model spec

### Sprint 2 — 独立入力フロー（`feature/sprint-2-serve-receive-input`）

- `config/routes.rb`: collection に `new_serve_receive` / `create_serve_receive` / `end_game_serve_receive` を追加
- `match_infos_controller.rb`: 上記アクション ＋ `create_game_from_patterns` 系 private メソッド
- View: `new_serve_receive` ＋ `_serve_receive_form` ＋ `_serve_receive_input`（試合情報・得点板は既存 partial 流用）
- `app/javascript/controllers/serve_receive_input_controller.js` 新規（origin 自動判定 → サーブ種類 複数選択 or レシーブ技術 → 攻撃技術 → 結果6ボタン → 次の得点。得点板連携）
- `index` 開始ボタン設置、request spec

### Sprint 3 — 専用分析ページ（`feature/sprint-3-serve-receive-analysis`）

- `app/services/serve_receive_analyzer.rb` 新規（集計）＋ service spec
- `show` に `if @match_info.serve_receive?` 分岐、`_serve_receive_analysis` partial
- 集計軸: ①サーブ別得点率 ②サーブ→3球目パターン別 ③レシーブ別 ④レシーブ→4球目パターン別 ⑤決着タイミング分布
- 表示は `_batting_score_table` 流用。組合せ別パターン（長さ＋回転＋3球目）は単一 batting_style キーで表せないため、ラベル文字列を受け取れる薄い派生 partial を用意（or `Score.human_enum_name` 直挿し部分を locals 化する小改修）

### Sprint 4 — UX強化＋AI連携（任意・`feature/sprint-4-serve-receive-ux`）

- 中断（interrupt）/ 前ゲームに戻る（undo）/ auto_save の新フロー対応
- `index` に analysis_type バッジ表示
- AIアドバイス連携（サーブ・レシーブ特化のプロンプト。`RallyContextBuilder` 流の `ServeReceiveContextBuilder`）
- system spec

## 検証方法（end-to-end）

1. `bundle exec rspec && bundle exec rubocop --parallel` が両方パス
2. `curl -s -o /dev/null -w "%{http_code}" http://localhost:3000` が 200
3. ブラウザ操作: 一覧 → 新規ボタン → 試合情報入力 → サーブ権選択 → サーブ起点（ショート＋下回転＋順横回転 / 3球目 fore_drive_vs_backspin / 3球目で得点）とレシーブ起点の両方を数点入力 → ゲーム終了 → 試合終了 → 分析ページで5軸の集計が正しく表示されることを確認

## 重要な注意点

- `analysis_type` のデフォルト 0=technique により、既存の試合入力フロー（`create`/`end_game`/`_form`/`_rally_input`）には一切手を入れずに済む。新フローは別アクション・別 partial・別 Stimulus controller で**完全並走**。
- enum はリポジトリの流儀どおりモデルに再掲（Score/Rally と同様のベタ書き）。

---

# Part 2: #77 以降のロードマップ（記録用）

> #77 完了後の方向性。各 Phase 着手時に改めて planner で詳細仕様を起こす。基本思想は「積み上げ型の価値はカレンダー時間でしか育たない → 集計基盤を早く出してデータ時計を回し、蓄積が育った頃に閲覧制限型フリーミアムで課金開始」。

## Phase 0: データ集計基盤 ＋ 成長ダッシュボード

- 複数試合をまたいだ技術別得点率の集計、月別/週別の時系列グラフ
- まずは「フォアドライブの得点率推移を月別表示」から作り、他分析に応用
- **狙い**: 既存データだけで作れて初日から価値が出る・低リスク・「積み上げは刺さるか」を最安で検証。データ時計を最速で回す。

## Phase 1: 対戦相手タイプ ＋ タイプ別分析

- 試合登録時に対戦相手タイプを選択（ドライブ型/カットマン/前陣速攻/ブロック型/サウスポー/ペンホルダー/その他）
- タイプ別勝率・技術別得点率。#77 と掛け合わせて「カットマン相手の3球目決定率」等が可能に
- **狙い**: 強い差別化ポイント。Phase 0 の集計エンジン上に軽く乗る。

## Phase 2: AI長期メモリ ＋ 月間成長レポート ＋ 練習メニュー提案

- 過去アドバイスの「要約」を保存し次回プロンプトへ（自分専用AIコーチ化、APIコスト配慮）
- 月間成長レポートのAI生成、練習メニュー提案
- **狙い**: 継続率を底上げ。Phase 0-1 で育ったデータがあって初めて中身が伴う。

## Phase 3: 収益化基盤の導入 💰課金開始

- Stripe 等の課金基盤
- **閲覧制限型フリーミアム**: 無料=直近◯試合＋基本分析、premium=長期推移/対戦相手分析/#77/AI履歴/成長レポート（データは消さず「価値ある分析だけ」を制限）
- premium に**初月無料トライアル**を付与（「初月無料・全機能有料」ではなく、永続無料枠＋premiumお試し）
- **狙い**: 売るに値する蓄積価値と、手放したくないユーザーが揃ってから課金。

## Phase 4: 用具データ連携（後回しでよい）

- ラバー/ラケット変更前後の比較、用具別勝率、AIによる用具提案
- **狙い**: 面白い差別化だが収益化の堀の本体ではない。課金開始後で十分。

## Phase 5: コミュニティ機能（収益化が回ってから）

- 成長共有（得点率の伸びをSNS投稿）→ いいね/コメント → クラブ/ランキング/チャレンジ
- ランキングは「勝率」より「成長系（最も改善した人・継続記録）」を優先（初心者が萎えない設計）
- **狙い**: Strava 型の継続フック。ただし分析価値が先、SNS化は最後。

