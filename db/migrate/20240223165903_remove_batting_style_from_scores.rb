class RemoveBattingStyleFromScores < ActiveRecord::Migration[7.1]
  def change
    remove_reference :scores, :batting_style, index: true, foreign_key: true
  end
end
