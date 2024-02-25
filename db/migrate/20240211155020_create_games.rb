class CreateGames < ActiveRecord::Migration[7.1]
  def change
    create_table :games do |t|
      t.references :match_info, foreign_key: true
      t.integer :game_number

      t.timestamps
    end
  end
end
