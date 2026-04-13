# Issue #100: 分析詳細ページに得点数と失点数の本数も表示

## Context

技術ごとの得点率ランキングテーブルには現在「技術」と「得点率 (%)」の2列のみ表示されている。
ユーザーが得点率の背景にある実際の本数（何本得点して何本失点したか）も確認できるよう、
「得点数」「失点数」列をテーブルに追加する。

DB変更なし。`Score`モデルの既存カラム `score`（得点数）と `lost_score`（失点数）を活用するだけ。

---

## 変更ファイル

### 1. `app/helpers/application_helper.rb`

`calculate_batting_score_data` が返すハッシュに `score` と `lost_score` を追加する。

**変更前:**
```ruby
{ batting_style: score.batting_style, rate: rate }
```

**変更後:**
```ruby
{ batting_style: score.batting_style, rate: rate, score: score.score, lost_score: score.lost_score }
```

### 2. `app/views/match_infos/_match_info_detail.html.erb`

テーブルのヘッダーに「得点数」「失点数」列を追加し、`tbody` でも対応するデータを表示する。

**変更前 (行41-52):**
```html
<thead>
  <tr>
    <th>技術</th>
    <th>得点率 (%)</th>
  </tr>
</thead>
<tbody>
  <% calculate_batting_score_data(@batting_scores).each do |data| %>
    <tr>
      <td><%= Score.human_enum_name(:batting_style, data[:batting_style]) %></td>
      <td><%= data[:rate] %></td>
    </tr>
  <% end %>
</tbody>
```

**変更後:**
```html
<thead>
  <tr>
    <th>技術</th>
    <th>得点率 (%)</th>
    <th>得点数</th>
    <th>失点数</th>
  </tr>
</thead>
<tbody>
  <% calculate_batting_score_data(@batting_scores).each do |data| %>
    <tr>
      <td><%= Score.human_enum_name(:batting_style, data[:batting_style]) %></td>
      <td><%= data[:rate] %></td>
      <td><%= data[:score] %></td>
      <td><%= data[:lost_score] %></td>
    </tr>
  <% end %>
</tbody>
```

---

## 検証

1. Docker環境を起動: `docker-compose up`
2. 試合データが入力済みの match_info の詳細ページを開く
3. 技術ごとの得点率ランキングテーブルに「得点数」「失点数」列が表示されることを確認
4. 各技術の得点率・得点数・失点数の値が正しく計算されていることを確認
5. `bundle exec rspec` でテストが通ることを確認
