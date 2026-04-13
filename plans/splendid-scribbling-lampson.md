# Plan: ChatGPT API gpt-4 → gpt-4o-mini アップグレード（Issue #94）

## Context

- **目的**: OpenAI APIのモデルを `gpt-4` から `gpt-4o-mini` にアップグレードする
- **理由**:
  - コスト削減（gpt-4 比で約1/30）
  - レスポンス速度の大幅改善
  - 今後のIssue #103（Workerの非同期停止）への布石。同期処理化した際にユーザー待ち時間を最小化するため、軽量・高速なモデルが必須
- **影響範囲**: 変更は実質1ファイルの1行だが、ドキュメント類も合わせて更新する

---

## 変更内容

### 1. ChatgptService モデル名変更（主要変更）

**ファイル**: `app/services/chatgpt_service.rb` (Line 26)

```ruby
# Before
model: "gpt-4",

# After
model: "gpt-4o-mini",
```

- `max_tokens: 800`, `temperature: 0.7` はそのまま維持（gpt-4o-mini は同パラメータに対応）
- API エンドポイント `https://api.openai.com/v1/chat/completions` も変更不要

---

### 2. README.md ドキュメント更新

**ファイル**: `README.md` (Line 237 付近)

```html
<!-- Before -->
<td>OpenAI API(モデル：gpt-4)</td>

<!-- After -->
<td>OpenAI API(モデル：gpt-4o-mini)</td>
```

---

### 3. CLAUDE.md ドキュメント更新

**ファイル**: `CLAUDE.md` (Line 74 付近)

```markdown
<!-- Before -->
- `OPENAI_API_KEY` - GPT-4 APIキー

<!-- After -->
- `OPENAI_API_KEY` - OpenAI APIキー（gpt-4o-mini）
```

---

## ブランチ戦略

```bash
git checkout -b feature/upgrade-chatgpt-to-gpt-4o-mini
```

---

## 検証方法

1. **ローカル動作確認**
   - `bin/dev` でサーバー起動
   - 試合データを登録してアドバイス生成が正常に動作するか確認
   - Rails ログで `model: "gpt-4o-mini"` がAPIリクエストに含まれていることを確認

2. **テスト実行**
   ```bash
   bundle exec rspec spec/models/match_info_update_advice_spec.rb
   bundle exec rspec spec/models/match_info_batting_score_data_spec.rb
   ```
   - 既存テストはモデル名に依存しないため、変更なしで通過するはず

3. **PR作成**
   - `.github/PULL_REQUEST_TEMPLATE.md` テンプレートを使用

---

## 変更ファイル一覧

| ファイル | 変更内容 |
|---------|---------|
| `app/services/chatgpt_service.rb` | `"gpt-4"` → `"gpt-4o-mini"` |
| `README.md` | モデル名の記載更新 |
| `CLAUDE.md` | モデル名の記載更新 |
