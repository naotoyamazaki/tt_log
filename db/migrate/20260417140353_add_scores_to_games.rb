class AddScoresToGames < ActiveRecord::Migration[7.1]
  def change
    add_column :games, :player_score, :integer
    add_column :games, :opponent_score, :integer
  end
end
