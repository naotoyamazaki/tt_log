class AddOwnErrorToRalliesAndScores < ActiveRecord::Migration[7.1]
  def change
    add_column :rallies, :point_type, :integer, null: false, default: 0
    add_column :scores, :own_error_count, :integer, null: false, default: 0
  end
end
