class CreateBattingStyles < ActiveRecord::Migration[7.1]
  def change
    create_table :batting_styles do |t|
      t.integer :style

      t.timestamps
    end
  end
end
