class AddMatchFormatToMatchInfos < ActiveRecord::Migration[7.1]
  def change
    add_column :match_infos, :match_format, :integer, default: 5
  end
end
