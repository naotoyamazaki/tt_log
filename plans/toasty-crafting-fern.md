# 打法に「ロビング」「サーブミス」を追加

## Context
「技術別得点率分析」の入力で「どの技術で得点した？」に表示される打法に、`ロビング`(lobbing)と`サーブミス`(serve_miss)を追加する。
`batting_style` は integer enum（DB制約・デフォルト値なし）のため、マイグレーションは不要。
現状の使用値は 0,1,4〜21。次の空き値は 22 から。

## 方針
- 値: `lobbing: 22`, `serve_miss: 23`（Score / Rally の両モデル）
- 入力画面: 「もっと見る」側に表示（`BATTING_STYLES_PRIMARY` は変更しない）
- `serve_miss` の意味:
  - 自分の得点側で選択 = 「相手のサーブミスで自分が得点」
  - 相手の得点側で選択 = 「自分のサーブミスで失点」
  - 両側とも同じボタン（「もっと見る」内）を表示し、集計側で得点/失点の文脈により解釈する（UI分岐は不要）
- `serve_miss` は自分の技術による得失点ではないため、`net_or_edge` と同様に AI 分析・技術別効率から除外（得点率表には表示）
  - AIへの文脈では、サーブミスはどちら側でも「技術」として扱わない（必要なら「相手サーブミスによる得点」「自サーブミスによる失点」の件数だけ補足として渡すかは実装時に判断）
- `ServeReceivePattern`（サーブレシーブ分析）側は今回のスコープ外

## 変更ファイル
1. `app/models/score.rb`（L5-17）: enum に `lobbing: 22, serve_miss: 23`
2. `app/models/rally.rb`（L6-18）: 同上
3. `config/locales/ja.yml`（L43-63 `score.batting_style`）: `lobbing: ロビング` / `serve_miss: サーブミス`
4. `app/javascript/controllers/rally_input_controller.js`（L3-24）: `BATTING_STYLE_NAMES` に追加。`BATTING_STYLES_ALL` は自動反映
5. `app/views/match_infos/_form_edit.html.erb`:
   - `batting_style_names`（L1-22）, `batting_styles_order`（L68-81）, `batting_style_options`（L82-95）に追加
   - `case score.batting_style` の `when` 列挙（L170-178）に追加（漏れると編集画面で入力欄が出ない）
6. `app/helpers/application_helper.rb`（L4-25）: `BATTING_STYLE_ABBR_MAP` に略称追加（例: Lob / 既存略称と衝突しないもの。`Sm` 等は要確認）
7. `app/services/rally_context_builder.rb`（L4-25）: `BATTING_STYLE_NAMES` に追加。`NET_OR_EDGE_STYLE` による除外処理（L91, L131, L153, L203 付近）を `serve_miss` にも適用（定数を配列化するなど、既存の書き方に合わせる）
8. `app/services/chatgpt_service.rb`（L52）: 「ネットorエッジは…含めないでください」にサーブミスも追記
9. `app/controllers/growth_dashboards_controller.rb`（L54-57）/ `Score.allowed_batting_styles`: 成長ダッシュボードの選択肢にサーブミスを出すかは実装時に確認（デフォルトは自動で含まれる）

## テスト
- `spec/models/rally_spec.rb`（L69-91）: 新enum値のテスト追加
- `spec/services/rally_context_builder_spec.rb`: serve_miss 除外・lobbing 集計のテスト
- `spec/helpers/application_helper_spec.rb`: 略称のテスト

## 検証
1. `bundle exec rspec && bundle exec rubocop --parallel`
2. `bin/dev` で試合入力 → 得点/失点どちらでも「もっと見る」にロビング・サーブミスが出て保存できる
3. 試合詳細の得点率表に日本語名で表示され、編集画面で得点数・失点数の入力欄が出る
4. AIアドバイスにサーブミスが技術として扱われないこと
5. 得点側・失点側のどちらでも「サーブミス」を選んで保存でき、表示上の意味が混同されないこと（得点側=相手のサーブミス、失点側=自分のサーブミス）

## 運用
- 新ブランチ（`feature/sprint-N-add-lobbing-serve-miss`）で実装、本plansファイルも同コミット
- マイグレーションなし（本番DB適用・dyno再起動の手順は不要。通常デプロイのみ）
