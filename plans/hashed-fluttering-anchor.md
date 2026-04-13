# Issue #103: workerでの非同期を停止

## Context

gpt-4o-mini への移行によりアドバイス生成が高速化（30秒以内）。
Heroku の worker dyno（Sidekiq）を停止することでインフラコストを削減する。

現状：AdviceGenerationJob（Sidekiq）で非同期にChatGPT APIを呼び出し → フロントエンドが3秒ごとにポーリングして結果を表示
変更後：show/update アクションでChatGPT APIを同期呼び出し → Herokuのweb dynoのみで完結

---

## 変更ファイル一覧

| ファイル | 変更内容 |
|---------|---------|
| `app/controllers/match_infos_controller.rb` | 非同期Job呼び出し → 同期処理に変更、advice_statusアクション削除 |
| `app/views/match_infos/_match_info_detail.html.erb` | Stimulusコントローラー属性を削除 |
| `Procfile` | `worker: bundle exec sidekiq` を削除 |
| `app/javascript/controllers/advice_controller.js` | ファイルを削除（ポーリング機能が不要） |
| `app/jobs/advice_generation_job.rb` | ファイルを削除 |
| `config/routes.rb` | `advice_status` メンバールートを削除 |

---

## 実装詳細

### 1. `app/controllers/match_infos_controller.rb`

**showアクション**（`advice_generating` を表示しなくなる）

```ruby
# 変更前
def show
  set_match_info_scores
  if @match_info.advice.present?
    @advice = @match_info.advice
  else
    AdviceGenerationJob.perform_later(@match_info.id)
    @advice = t('notices.advice_generating')
  end
end

# 変更後
def show
  set_match_info_scores
  if @match_info.advice.present?
    @advice = @match_info.advice
  else
    advice = ChatgptService.get_advice(@match_info.batting_score_data.to_json)
    @match_info.update_column(:advice, advice)
    @advice = advice
  end
end
```

**update_advice_if_neededメソッド**

```ruby
# 変更前
def update_advice_if_needed(original_data)
  return unless batting_score_changed?(original_data)
  @match_info.update(advice: nil)
  AdviceGenerationJob.perform_later(@match_info.id)
end

# 変更後
def update_advice_if_needed(original_data)
  return unless batting_score_changed?(original_data)
  @match_info.update(advice: nil)
  advice = ChatgptService.get_advice(@match_info.batting_score_data.to_json)
  @match_info.update_column(:advice, advice)
end
```

**advice_statusアクション**を削除（ポーリング廃止により不要）

### 2. `config/routes.rb`

```ruby
# 削除するルート
member do
  get :advice_status
end
```

### 3. `app/views/match_infos/_match_info_detail.html.erb`

```erb
# 変更前
<div class="advice-section"
     data-controller="advice"
     data-advice-id-value="<%= @match_info.id %>"
     data-advice-url-value="<%= advice_status_match_info_path(@match_info) %>">
  <p data-advice-target="text"><%= @advice %></p>
</div>

# 変更後
<div class="advice-section">
  <p><%= @advice %></p>
</div>
```

### 4. `Procfile`

```
# 変更前
web: bundle exec rails server -b 0.0.0.0 -p $PORT
worker: bundle exec sidekiq

# 変更後
web: bundle exec rails server -b 0.0.0.0 -p $PORT
```

### 5. 削除するファイル

- `app/javascript/controllers/advice_controller.js`
- `app/jobs/advice_generation_job.rb`

---

## 注意事項

- Sidekiq gem (`gem 'sidekiq'`) と `config/initializers/sidekiq.rb` はこの PR では削除しない（Heroku dyno停止で十分コスト削減、gem削除は別タスクで対応）
- Heroku側でworker dynoを停止する作業は別途必要（本PR外）
- gpt-4o-miniが30秒以内に応答しないケースでHerokuの30秒タイムアウトが発生する可能性あり（稀なエラーとして許容）

---

## 検証方法

1. `bin/dev` でローカル起動
2. 試合データを新規作成 → show画面で **ローディングなしに即座にアドバイスが表示** されることを確認
3. スコアを編集して保存 → アドバイスが更新されることを確認
4. `bundle exec rspec spec/` でテストがパスすること
5. ルーティング確認: `rails routes | grep advice_status` で何も表示されないこと
