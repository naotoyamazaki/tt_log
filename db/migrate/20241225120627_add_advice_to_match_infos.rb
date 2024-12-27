class AddAdviceToMatchInfos < ActiveRecord::Migration[7.1]
  def change
    add_column :match_infos, :advice, :text
  end
end
