# 編集フォーム ↔ 得点推移表 同期スプリント

## Context

Sprint 1〜3でラリー入力UI（新規フォーム）と得点推移表を実装した。新規フォームは Rally→Score の流れでデータを保存するが、編集フォーム（`_form_edit.html.erb`）は従来の Score 直接編集のまま更新されていない。

**問題点：**
- `update` メソッドは Score を nested_attributes で更新するが、Rally レコードはそのまま放置される
- `show.html.erb` の得点推移表は `@match_info.rallies` を読むため、Score を編集しても推移表に変更が反映されない
- ユーザーは「編集したのになぜ推移表が古いまま？」という混乱を招く

---

## 変更方針

編集フォームの入力方式（Score 直接編集）は維持する（シンプルで使いやすいUX）。  
ただし保存時に **Rally レコードを Score データから再生成** し、推移表が更新された得点を反映するようにする。

- Rally がある試合（新規フォームで作成）→ 保存後に Rally を再生成
- Rally がない試合（レガシーデータ）→ 従来通り変更なし（推移表は非表示のまま）

生成される Rally はゲーム内でプレイヤー/相手の得点をラウンドロビン方式でインターリーブする（例：score=5, lost_score=3 → P,O,P,O,P,O,P,P）。元の rally 順序は失われるが、得点数は正確に反映される。

---

## 変更ファイル

### 1. `app/controllers/match_infos_controller.rb`

**`update` メソッドに Rally 再生成の呼び出しを追加：**

```ruby
def update
  set_players
  original_batting_score_data = fetch_batting_score_data(@match_info)

  if update_match_info
    @match_info.games.each(&:recalculate_scores)
    regenerate_rallies_from_scores(@match_info) if @match_info.rallies.any?  # ← 追加
    update_advice_if_needed(original_batting_score_data)
    update_response(success: true, notice: t('notices.match_info_updated'))
  else
    update_response(success: false)
  end
end
```

**新規プライベートメソッド `regenerate_rallies_from_scores` を追加：**

```ruby
def regenerate_rallies_from_scores(match_info)
  match_info.games.each do |game|
    game.rallies.destroy_all
    seq = 1
    game.scores.sort_by(&:id).each do |score|
      player_left = score.score.to_i
      opponent_left = score.lost_score.to_i
      while player_left > 0 || opponent_left > 0
        [:player, :opponent].each do |side|
          next unless side == :player ? player_left > 0 : opponent_left > 0

          match_info.rallies.create!(
            game: game, game_number: game.game_number,
            sequence_number: seq, winner: side, batting_style: score.batting_style
          )
          side == :player ? player_left -= 1 : opponent_left -= 1
          seq += 1
        end
      end
    end
  end
end
```

> RuboCop 対策：メソッド分割が必要なら `emit_rally_records(match_info, game, score, seq)` に切り出す。

### 2. `app/views/match_infos/_form_edit.html.erb`

現在の説明文（行99）に得点推移表への反映を示す一文を追加：

```
編集したいゲームのタブを選択して、各技術の得点・失点数を修正してください。
保存後、得点推移表にも変更が反映されます。
```

---

## 変更しないもの

- `_form_edit.html.erb` の入力UI構造（Score 直接編集）はそのまま維持
- レガシーデータ（Rally なし）のフォール処理はそのまま維持
- `recalculate_scores` の呼び出しは既存のまま維持

---

## スペック

`spec/requests/match_infos_controller_spec.rb`（または対応するファイル）に以下を追加：

- Rally ありの試合を PATCH で更新すると Rally が再生成されること
- 更新後の Rally 数 = Score の score + lost_score の総和（ゲームごとに）
- Rally なしの試合を更新しても Rally は作成されないこと

---

## 検証手順

1. `bin/dev` でサーバー起動
2. ラリー入力で試合を新規作成 → show ページで得点推移表が表示されることを確認
3. 試合を編集 → いずれかのゲームで得点を変更して保存
4. show ページに戻り、得点推移表の得点列数（セル数）が変更後の値と一致していることを確認
5. `bundle exec rspec && bundle exec rubocop --parallel` がパスすることを確認
