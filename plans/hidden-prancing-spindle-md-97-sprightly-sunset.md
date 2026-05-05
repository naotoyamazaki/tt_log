# #97 分析項目追加（ドライブ分類・スマッシュ・ネットorエッジ）

## Context

batting_style enum の「フォアドライブ」「バックドライブ」は、対上回転/対下回転で戦略が大きく異なるため分析精度が低い。
これを細分化し、加えてスマッシュ・ネットorエッジを追加することで、より詳細な技術分析とAIアドバイスの質向上を図る。

---

## 変更概要

### 削除
| enum名 | 整数値 | 日本語名 |
|--------|--------|----------|
| `fore_drive` | 2 | フォアドライブ |
| `back_drive` | 3 | バックドライブ |

### 追加
| enum名 | 整数値 | 日本語名 |
|--------|--------|----------|
| `fore_drive_vs_topspin` | 15 | 対上回転フォアドライブ |
| `back_drive_vs_topspin` | 16 | 対上回転バックドライブ |
| `fore_drive_vs_backspin` | 17 | 対下回転フォアドライブ |
| `back_drive_vs_backspin` | 18 | 対下回転バックドライブ |
| `fore_smash` | 19 | フォアスマッシュ |
| `back_smash` | 20 | バックスマッシュ |
| `net_or_edge` | 21 | ネットorエッジ |

> **補足**: `net_or_edge` は技術ではなく偶発的な得点状況だが、試合記録・統計として追跡する価値があるため追加。

### 追加提案（ユーザー判断）
現状のリストは十分だが、以下も検討の余地あり（今回のスコープ外）:
- `fore_lob` / `back_lob`（フォアロビング/バックロビング）— 守備型選手に有用
- `fore_meet` / `back_meet`（ミート打ち）— 台上技術の延長として

---

## 既存データ移行方針

- `fore_drive`（整数値 2）→ `fore_drive_vs_topspin`（整数値 15）に UPDATE
- `back_drive`（整数値 3）→ `back_drive_vs_topspin`（整数値 16）に UPDATE
- マイグレーションで SQL UPDATE を実行し、その後 enum から 2・3 を削除

---

## Sprint 1: DBマイグレーション・モデル・ロケール更新

**ブランチ**: `feature/sprint-1-batting-style-expansion`

### 変更ファイル

#### 1. `db/migrate/YYYYMMDDHHMMSS_expand_batting_styles.rb`（新規）
```ruby
class ExpandBattingStyles < ActiveRecord::Migration[7.1]
  def up
    # 既存データ移行: fore_drive(2) → fore_drive_vs_topspin(15)
    execute "UPDATE scores SET batting_style = 15 WHERE batting_style = 2"
    # 既存データ移行: back_drive(3) → back_drive_vs_topspin(16)
    execute "UPDATE scores SET batting_style = 16 WHERE batting_style = 3"
  end

  def down
    execute "UPDATE scores SET batting_style = 2 WHERE batting_style = 15"
    execute "UPDATE scores SET batting_style = 3 WHERE batting_style = 16"
    execute "DELETE FROM scores WHERE batting_style IN (17, 18, 19, 20, 21)"
  end
end
```

#### 2. `app/models/score.rb`
- enum から `fore_drive: 2`, `back_drive: 3` を削除
- 新規 7 項目を追加（整数値 15〜21）

```ruby
enum :batting_style, {
  serve: 0, receive: 1,
  fore_drive_vs_topspin: 15, back_drive_vs_topspin: 16,
  fore_drive_vs_backspin: 17, back_drive_vs_backspin: 18,
  fore_push: 4, back_push: 5,
  fore_stop: 6, back_stop: 7,
  fore_flick: 8, back_flick: 9,
  chiquita: 10, fore_block: 11,
  back_block: 12, fore_counter: 13,
  back_counter: 14,
  fore_smash: 19, back_smash: 20,
  net_or_edge: 21
}
```

#### 3. `config/locales/ja.yml`
- `fore_drive` / `back_drive` エントリを削除
- 新規 7 項目の日本語訳を追加

```yaml
fore_drive_vs_topspin: 対上回転フォアドライブ
back_drive_vs_topspin: 対上回転バックドライブ
fore_drive_vs_backspin: 対下回転フォアドライブ
back_drive_vs_backspin: 対下回転バックドライブ
fore_smash: フォアスマッシュ
back_smash: バックスマッシュ
net_or_edge: ネットorエッジ
```

#### 4. `app/models/match_info.rb`
- `translated_batting_style_name` メソッドの `fore_push`/`back_push` 特別処理はそのまま維持
- 新項目は I18n で自動翻訳されるため追加対応不要

---

## Sprint 2: フォーム・ビュー・スペック更新

**ブランチ**: `feature/sprint-2-batting-style-form-views`

### 変更ファイル

#### 5. `app/views/match_infos/_form.html.erb`
`batting_style_names` ハッシュを更新:
```ruby
batting_style_names = {
  'fore_drive_vs_topspin'  => '対上回転フォアドライブ',
  'back_drive_vs_topspin'  => '対上回転バックドライブ',
  'fore_drive_vs_backspin' => '対下回転フォアドライブ',
  'back_drive_vs_backspin' => '対下回転バックドライブ',
  'fore_push'    => 'フォアツッツキ',
  'back_push'    => 'バックツッツキ',
  ...（既存を維持）...
  'fore_smash'   => 'フォアスマッシュ',
  'back_smash'   => 'バックスマッシュ',
  'net_or_edge'  => 'ネットorエッジ',
}
```

#### 6. `app/views/match_infos/_form_edit.html.erb`
- `batting_styles_order` 配列から `fore_drive`, `back_drive` を削除し、新項目を追加
- `batting_style_options` セレクト配列も同様に更新

```ruby
batting_styles_order = %w[
  serve
  fore_drive_vs_topspin back_drive_vs_topspin
  fore_drive_vs_backspin back_drive_vs_backspin
  fore_push back_push
  fore_stop back_stop
  fore_flick back_flick
  chiquita
  fore_block back_block
  fore_counter back_counter
  fore_smash back_smash
  net_or_edge
]
```

#### 7. `app/helpers/application_helper.rb`
`abbreviate_batting_style` メソッドに `対上回転` / `対下回転` の置換を追加する。
ドライブ・スマッシュ・ネットorエッジはそのまま維持。

```ruby
def abbreviate_batting_style(name)
  name.gsub('フォア', 'F').gsub('バック', 'B')
      .gsub('対上回転', '対上').gsub('対下回転', '対下')
end
```

モバイル表示での略称例：
| フル名称 | 略称 |
|----------|------|
| 対上回転フォアドライブ | 対上Fドライブ |
| 対上回転バックドライブ | 対上Bドライブ |
| 対下回転フォアドライブ | 対下Fドライブ |
| 対下回転バックドライブ | 対下Bドライブ |
| フォアスマッシュ | Fスマッシュ |
| バックスマッシュ | Bスマッシュ |
| ネットorエッジ | ネットorエッジ（変更なし） |

#### 8. スペックファイル更新
- `spec/factories/scores.rb`: デフォルト `batting_style` を `fore_drive` → `fore_drive_vs_topspin` に変更
- `spec/models/match_info_batting_score_data_spec.rb`: `fore_drive` → `fore_drive_vs_topspin` に変更、期待文字列も更新
- `spec/models/match_info_spec.rb`: `fore_drive` 参照を更新
- `spec/requests/match_infos_spec.rb`: `"fore_drive"` キー参照を更新

---

## 表示順序（フォーム）

```
サーブ
対上回転フォアドライブ / 対上回転バックドライブ
対下回転フォアドライブ / 対下回転バックドライブ
フォアツッツキ / バックツッツキ
フォアストップ / バックストップ
フォアフリック / バックフリック
チキータ
フォアブロック / バックブロック
フォアカウンター / バックカウンター
フォアスマッシュ / バックスマッシュ
ネットorエッジ
```

---

## 検証方法

1. `bundle exec rails db:migrate` を実行し、マイグレーション成功を確認
2. `rails console` で `Score.batting_styles` を確認し、`fore_drive`/`back_drive` が消えていることを確認
3. ブラウザで `/match_infos/new` を開き、新しい技術名が表示されることを確認
4. 既存試合データの編集画面で移行されたデータが正しく表示されることを確認
5. `bundle exec rspec && bundle exec rubocop --parallel` がすべてパスすること
