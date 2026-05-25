# Sprint 4: AI分析強化 — サーブ権データ活用プロンプト刷新

## Context

Sprint 1〜3でラリー順入力・得点推移表が完成し、各ラリーのデータ（`rallies` テーブル）と  
ゲームごとのサーブ権（`games.first_server`）が蓄積されるようになった。  
しかし現行の `ChatgptService` は技術別通算得失点（旧来の `batting_score_data`）しか使っておらず、  
試合の「流れ」「サーブ/レシーブ局面の差」「接戦時の傾向」がAIに伝わっていない。  
Sprint 4 では `RallyContextBuilder` サービスを新設してラリーデータを多角的に分析し、  
より実践的なコーチングアドバイスを生成できるようにプロンプトを全面刷新する。

---

## 実装方針

### 1. `RallyContextBuilder` サービス新規作成

**ファイル**: `app/services/rally_context_builder.rb`

`MatchInfo` を受け取り、以下 4 種類のコンテキスト文字列を組み立てる。

#### (A) 技術別得点効率（`technique_efficiency_text`）

- Rally レコードを技術ごとにグループ化し、勝率（得点数 / 総本数）を計算
- 勝率の高い順に並べた文字列を返す
- 例: `"フォアドライブ（対上回転）: 得点 8 / 失点 3（勝率 73%）"`

#### (B) サーブ/レシーブ局面分析（`serve_situation_text`）

- `game.first_server` と `rally.sequence_number` から各ラリーのサーブ権を計算
  - 0〜19本目: `floor(seq / 2) % 2 == 0` なら初期サーバー側
  - 20本目以降: `seq % 2 == 0` なら初期サーバー側
- 自分のサーブ時 / 相手のサーブ時それぞれの得点率と主力技術を集計
- 例:
  ```
  自分のサーブ時: 得点率 62%（得点 13 / 失点 8）
  相手のサーブ時: 得点率 41%（得点 9 / 失点 13）
  ```

#### (C) スコア状況別分析（`situation_stats_text`）

- 各ラリー時点のスコアを `sequence_number` と `winner` から再構築し、得点時のスコア差を分類
  - **接戦** : |差| ≤ 2
  - **リード時** : 自分が +3 以上リード
  - **ビハインド時** : 相手が +3 以上リード
  - **デュース** : 両者 ≥ 10 かつ |差| ≤ 2
- 例: `"接戦（±2点差）: 得点率 55%（得点 11 / 失点 9）"`

#### (D) 連続失点パターン（`momentum_text`）

- `sequence_number` の順でラリーを走査し、連続失点の最大数を集計
- 連続失点から最初に得点したラリーの技術を「立て直し技術」として抽出
- 例: `"最大連続失点: 4本 / 立て直し技術: フォアドライブ（対上回転）(3回), サーブ(2回)"`

#### フォールバック

`match_info.rallies.none?` の場合（旧来の入力データのみ）は  
`RallyContextBuilder` を使わず、既存の `batting_score_data` / `game_by_game_score_data` で  
旧来プロンプトにフォールバックする。

---

### 2. `ChatgptService` プロンプト全面刷新

**ファイル**: `app/services/chatgpt_service.rb`

#### シグネチャ変更

```ruby
# 変更前
def self.get_advice(batting_score_data, game_data = nil)

# 変更後
def self.get_advice(match_info)
```

#### 新しいシステムプロンプト

```
あなたは経験豊富な卓球コーチです。
提供されるデータは実際の試合を1ラリーずつ記録したものです。
データを深く分析し、選手が次の練習・試合で即座に実践できる具体的なアドバイスを作成してください。
```

#### 新しいユーザーメッセージ（ラリーデータあり）

```
以下は卓球の試合データです。日本語で5項目のアドバイスを作成してください。
なお、フォアプッシュはフォアツッツキ、バックプッシュはバックツッツキと表示してください。

【試合結果】
{game_count_score}（ゲームスコア: {各ゲームのスコア}）

【技術別得点効率（高勝率→低勝率）】
{technique_efficiency_text}

【サーブ・レシーブ局面分析】
{serve_situation_text}

【スコア状況別分析】
{situation_stats_text}

【連続失点パターン】
{momentum_text}

以下の5項目について、具体的なアドバイスを作成してください:
1. サーブ戦術の改善
2. レシーブ戦術の改善
3. 得意技術の活用戦略
4. 弱点技術の改善方法
5. 接戦・大事な局面での対処法

アドバイス:
```

#### パラメータ調整

- `max_tokens`: 800 → **1200**（詳細なアドバイスに対応）
- `temperature`: 0.7 のまま

---

### 3. コントローラー修正

**ファイル**: `app/controllers/match_infos_controller.rb`

#### (a) `show` アクション（1箇所のみ残す）

アドバイスは `show` アクションで **一度だけ** 生成する。`advice` カラムが埋まっていれば再生成しない。

```ruby
# 変更後（show アクション）
advice = ChatgptService.get_advice(@match_info)
```

#### (b) `update_advice_if_needed` を無効化

編集ページ（`update` アクション）からのスコア変更でアドバイスを再生成しないよう、  
`update_advice_if_needed` の呼び出しを削除する。  
アドバイスは一度生成したら固定とし、編集操作では上書きしない。

```ruby
# 削除対象（update アクション内）
update_advice_if_needed(original_data)

# 合わせて以下のメソッドも削除
# - update_advice_if_needed
# - batting_score_changed?
# - fetch_batting_score_data（update_advice_if_needed からしか使われていない場合）
```

---

### 4. RSpecテスト

**新規**: `spec/services/rally_context_builder_spec.rb`

- `technique_efficiency_text` が勝率降順で返ること
- `serve_situation_text` がサーブ権を正しく計算すること（20点前後のルール境界含む）
- `situation_stats_text` がスコア差による分類を正しく行うこと
- `momentum_text` が連続失点を正しく集計すること
- rallies が空の場合でも例外が出ないこと（フォールバック）

**更新**: `spec/services/chatgpt_service_spec.rb`（既存があれば）

- 新シグネチャ `get_advice(match_info)` のテストに更新

---

## 変更ファイル一覧


| ファイル                                          | 種別                      |
| --------------------------------------------- | ----------------------- |
| `app/services/rally_context_builder.rb`       | 新規作成                    |
| `app/services/chatgpt_service.rb`             | 修正（シグネチャ・プロンプト刷新）       |
| `app/controllers/match_infos_controller.rb`   | 修正（show のみ get_advice 呼び出し、update_advice_if_needed を削除） |
| `spec/services/rally_context_builder_spec.rb` | 新規作成                    |
| `spec/services/chatgpt_service_spec.rb`       | 修正（あれば）                 |


---

## 検証手順

1. `bundle exec rspec spec/services/rally_context_builder_spec.rb` でユニットテストパス確認
2. `bundle exec rspec && bundle exec rubocop --parallel` でフルチェックパス確認
3. ローカル環境でラリーデータ入り試合の show ページを開き、
   アドバイスに「サーブ時」「レシーブ時」「接戦」などの文言が含まれることを目視確認
4. rallies が空の旧来試合でもアドバイスが正常生成されることを確認（フォールバック動作）
5. 編集ページでスコアを変更して保存しても、show ページのアドバイスが変わらないことを確認

