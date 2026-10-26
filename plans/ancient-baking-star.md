# 対戦相手タイプ属性の表示追加（一覧カード＋詳細ページ）

## Context（なぜこの実装をするのか）

Phase 1（`plans/1-2-3-tranquil-kite.md`）のSprint 2で、試合登録フォームに対戦相手のタイプ属性（利き手・ラケット・ラバー（フォア/バック）・戦型）を入力できるようにした。しかし入力した値は現在、編集フォームを開かない限り再確認できず、「選択したタイプデータが分析後に表示されなくなってしまう」という問題がある。

ユーザーと相談の上、以下の折衷案で対応する：
- **一覧カード**：場所が限られるため「戦型」のみバッジで表示する（既存の分析タイプバッジと同じスタイル）
- **詳細ページ**：利き手・ラケット・ラバー（フォア/バック）・戦型（その他の場合は自由入力も）を全て表示する

この表示追加はSprint 3（growth_dashboardsへの戦型フィルタ・勝率集計）とは独立したスコープのため、別ブランチ・別PRとして進める。Sprint 1・2はmainにマージ済みのため、最新のmainから新規ブランチを切って実装する（Sprint 3のマージは待たない）。

## 実装方針

### 1. 詳細ページ（`show.html.erb`）に対戦相手情報セクションを追加

新規partial `app/views/match_infos/_opponent_attributes_summary.html.erb` を作成し、以下を表示する：
- 利き手・ラケット・ラバー（フォア）・ラバー（バック）・戦型を、既存の`section-card`スタイル（`_match_info_detail.html.erb`の「試合情報」セクションと同じクラス）に沿って表示
- 各属性は値が設定されている場合のみ行を表示（未設定の項目は非表示。6項目全部nilの場合はセクション自体を表示しない）
- 戦型が`other`の場合は`opponent_playstyle_other`の自由入力値も合わせて表示（例: `その他（変則）`）
- 表示文字列は`MatchInfo.human_enum_name(:opponent_handedness, match_info.opponent_handedness)`等、Sprint 1で実装済みのメソッドを使う

`app/views/match_infos/show.html.erb` の1行目（`<h1>`）の直後、`<% if @match_info.serve_receive? %>`の分岐より前に、このpartialをrenderする一行を追加する。これにより技術別分析・サーブレシーブ分析どちらの試合でも対戦相手情報が表示される（現状`_match_info_detail.html.erb`内の「試合情報」セクションはテクニック分析時のみ表示されており、サーブレシーブ分析時は表示されないため、分岐の外に出す）。

### 2. 一覧カード（`_match_info_summary.html.erb`）に戦型バッジを追加

既存の分析タイプバッジ（19〜23行目、`サーブ・レシーブ`/`技術別得点率`）の直後に、`match_info.opponent_playstyle.present?`の場合のみ戦型バッジを追加する。
- 表示文言: `MatchInfo.human_enum_name(:opponent_playstyle, match_info.opponent_playstyle)`（例: `カットマン`）
- バッジスタイルは既存バッジ（`badge bg-info text-dark` 等）に揃えた新しい配色クラス（例: `badge bg-light text-dark border`）を使い、既存の2バッジと視覚的に区別する

### 3. テスト

- system spec（`spec/system/match_infos_spec.rb`）: 対戦相手タイプを設定して試合を保存した場合、詳細ページに利き手・ラケット・ラバー・戦型（その他の場合は自由入力含む）が表示されること、一覧カードに戦型バッジが表示されること。未設定の場合はセクション・バッジが表示されないこと（既存試合データとの後方互換）
- サーブレシーブ分析（`analysis_type: serve_receive`）の試合でも詳細ページに対戦相手情報セクションが表示されることを確認するケースを追加

### Sprint末の確認
`bundle exec rspec && bundle exec rubocop --parallel` が両方パスすること。RuboCopの最大行長120文字・メソッド長20行・クラス長200行を守ること。

## 制約（CLAUDE.md準拠）
- ブランチ名: `feature/opponent-attributes-display`（最新mainから新規に切る。Sprint 3のブランチ・PRとは独立）
- 実装後は `bundle exec rspec && bundle exec rubocop --parallel` が両方パスすることを確認する
- PRの作成はユーザーが明示的に指示するまで行わない
- コミットメッセージの末尾に `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>` を付与する
- 実装はgeneratorエージェントに依頼し、完了後はevaluatorエージェントによる動作検証（ブラウザでの実機確認含む）を行う

## Critical Files
- `app/views/match_infos/show.html.erb`
- `app/views/match_infos/_opponent_attributes_summary.html.erb`（新規）
- `app/views/match_infos/_match_info_summary.html.erb`
- `spec/system/match_infos_spec.rb`

## 検証方法
- 対戦相手タイプを全て設定した試合（技術別分析・サーブレシーブ分析それぞれ）を登録し、詳細ページに6項目が表示されること、一覧カードに戦型バッジが表示されることをブラウザで確認する
- 未設定のまま保存した試合では、詳細ページの対戦相手情報セクションと一覧カードの戦型バッジがどちらも表示されないことを確認する
- 既存のmatch_infos関連request/system specにデグレードがないことを確認する
