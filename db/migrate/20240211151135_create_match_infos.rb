class CreateMatchInfos < ActiveRecord::Migration[7.1]
  def change
    create_table :match_infos do |t|
      t.references :user, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: { to_table: :players }
      t.references :opponent, null: false, foreign_key: { to_table: :players }
      t.date :match_date
      t.string :match_name
      t.text :memo

      t.timestamps
    end
  end
end
