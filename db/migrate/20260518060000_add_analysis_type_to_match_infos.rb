class AddAnalysisTypeToMatchInfos < ActiveRecord::Migration[7.1]
  def change
    add_column :match_infos, :analysis_type, :integer, null: false, default: 0
  end
end
