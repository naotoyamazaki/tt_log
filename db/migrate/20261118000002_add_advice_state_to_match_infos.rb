class AddAdviceStateToMatchInfos < ActiveRecord::Migration[7.1]
  def change
    add_column :match_infos, :advice_generating_at, :datetime
    add_column :match_infos, :advice_failed_at, :datetime
  end
end
