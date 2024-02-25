class DropBattingStyleTable < ActiveRecord::Migration[7.1]
  def up
    drop_table :batting_styles
  end
    
  def down
    create_table :batting_styles do |t|
      t.integer :style

      t.timestamps
    end
  end
end
