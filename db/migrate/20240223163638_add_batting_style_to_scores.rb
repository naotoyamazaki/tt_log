class AddBattingStyleToScores < ActiveRecord::Migration[7.1]
  def change
    add_column :scores, :batting_style, :integer, null: false
  end
end
