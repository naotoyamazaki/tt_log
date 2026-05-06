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
