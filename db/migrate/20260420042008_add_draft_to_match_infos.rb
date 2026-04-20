class AddDraftToMatchInfos < ActiveRecord::Migration[7.1]
  def change
    add_column :match_infos, :draft, :boolean, default: false, null: false
  end
end
