class AddFirstServerToGames < ActiveRecord::Migration[7.1]
  def change
    add_column :games, :first_server, :integer
  end
end
