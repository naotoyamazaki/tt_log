# Context

以前に作成した Planner・Generator・Evaluator の3つを、**Skill（スキル）ではなくAgent（エージェント）**として再作成する。

Skill はグローバルな `~/.claude/plugins/` 配下に置く必要があったが、Agent はリポジトリ内の `.claude/agents/` ディレクトリに置くだけで認識される。シンプルかつプロジェクトに紐付けて管理できる。

---

# 実装手順

## Step 1: 既存の SKILL.md ファイルを削除

`~/.claude/plugins/` 配下の planner・generator・evaluator の SKILL.md とディレクトリを削除する。

削除対象:
- `~/.claude/plugins/marketplaces/local/plugin/skills/planner/SKILL.md`
- `~/.claude/plugins/marketplaces/local/plugin/skills/generator/SKILL.md`
- `~/.claude/plugins/marketplaces/local/plugin/skills/evaluator/SKILL.md`
- `~/.claude/plugins/cache/local/app-builder/1.0.0/skills/planner/SKILL.md`
- `~/.claude/plugins/cache/local/app-builder/1.0.0/skills/generator/SKILL.md`
- `~/.claude/plugins/cache/local/app-builder/1.0.0/skills/evaluator/SKILL.md`

ディレクトリ（`skills/`）もまとめて削除する。

## Step 2: `.claude/agents/` ディレクトリに Agent ファイルを作成

```
/Users/matsudairakenta/tt_log/.claude/agents/
├── planner.md
├── generator.md
└── evaluator.md
```

### Agent ファイルフォーマット

```markdown
---
name: planner
description: [いつこのエージェントを使うか — トリガー文言、ユースケースを含む]
model: opus  # オプション
---

[エージェント自身へのシステムプロンプト。「あなたは〜エージェントです」という一人称で記述]
```

既存の SKILL.md の内容を以下の観点で変換する:
- SKILL.md は「Claudeに対する手順書」→ Agent は「エージェント自身へのシステムプロンプト」
- description（frontmatter）はトリガー文言を含む簡潔な説明

### 各エージェントのモデル指定

| エージェント | 推奨モデル | 理由 |
|-------------|-----------|------|
| Planner     | opus      | 創造的・包括的な仕様展開が必要 |
| Generator   | sonnet    | コード実装は Sonnet で十分高品質 |
| Evaluator   | sonnet    | テスト実行・判定は Sonnet で十分 |

---

# 各エージェントの内容設計

## Planner エージェント（planner.md）

**役割**: 1〜4行の短い説明を受け取り、詳細な製品仕様書に展開する

**システムプロンプトのポイント**:
- 「何を作るか」に集中し、技術実装詳細には踏み込まない（下流への伝播コスト）
- 野心的に展開する（1スプリント5〜15機能）
- 仕様書構成テンプレートに従う（概要・機能一覧・ユーザーストーリー・スコープ外・成功指標）
- `plans/{kebab-case}.md` に保存し、Generator への引き渡し手順を案内
- 仕様書出力後「このスコープで合っていますか？」と確認を取る

## Generator エージェント（generator.md）

**役割**: 仕様書のスプリントを1つずつ実装し、自己評価後に Evaluator へ引き渡す

**システムプロンプトのポイント**:
- スプリントを1つずつ実装（スキップしない）
- 仕様書の「何を」に忠実、「どう」は自分で判断
- 自己評価チェックリスト（全機能動作、起動確認、Lint/テストパス）
- Evaluator への引き渡しレポート形式を守る
- Evaluator から不合格フィードバックを受けたときの修正フロー（3回失敗でユーザー相談）

## Evaluator エージェント（evaluator.md）

**役割**: Playwright MCP を使って実際のアプリを操作・検証し、合否レポートを出力する

**システムプロンプトのポイント**:
- Playwright MCP ツールを積極的に使用（利用不可の場合は Bash で実行）
- 5つの評価基準（機能完成度・UI表示・エラーハンドリング・デグレード・ページ遷移）
- 1基準でも閾値未満 → 不合格
- 合格/不合格レポートの出力形式に従う
- 「推測でパスしない」原則、スクリーンショットを証拠に残す

---

# 変更対象ファイル

| ファイル | 操作 |
|---------|------|
| `~/.claude/plugins/marketplaces/local/plugin/skills/` ディレクトリ | 削除（中身ごと） |
| `~/.claude/plugins/cache/local/app-builder/1.0.0/skills/` ディレクトリ | 削除（中身ごと） |
| `.claude/agents/planner.md` | 新規作成 |
| `.claude/agents/generator.md` | 新規作成 |
| `.claude/agents/evaluator.md` | 新規作成 |

---

# 検証方法

1. Claude Code を再起動
2. Agent tool の利用可能エージェント一覧に `planner`, `generator`, `evaluator` が表示される
3. `planner` エージェントに「ToDoアプリを作って」と渡して仕様書が生成される
4. Skill として認識されなくなっていること（skill一覧から消えている）を確認
