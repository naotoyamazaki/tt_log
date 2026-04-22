class AddPartialGameDataToMatchInfos < ActiveRecord::Migration[7.1]
  def change
    add_column :match_infos, :partial_game_data, :jsonb
  end
end
