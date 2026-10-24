class AddOpponentAttributesToMatchInfos < ActiveRecord::Migration[7.1]
  def change
    add_column :match_infos, :opponent_handedness, :integer
    add_column :match_infos, :opponent_racket, :integer
    add_column :match_infos, :opponent_rubber_forehand, :integer
    add_column :match_infos, :opponent_rubber_backhand, :integer
    add_column :match_infos, :opponent_playstyle, :integer
    add_column :match_infos, :opponent_playstyle_other, :string
  end
end
