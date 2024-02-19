class CreateScores < ActiveRecord::Migration[7.1]
  def change
    create_table :scores do |t|
      t.references :match_info, null: false, foreign_key: true
      t.references :batting_style, null: false, foreign_key: true
      t.references :game, null: false, foreign_key: true
      t.integer :score
      t.integer :lost_score

      t.timestamps
    end
  end
end
