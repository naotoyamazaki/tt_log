class CreateRallies < ActiveRecord::Migration[7.1]
  def change
    create_table :rallies do |t|
      t.references :match_info, null: false, foreign_key: true
      t.references :game, null: true, foreign_key: true
      t.integer :game_number, null: false
      t.integer :sequence_number, null: false
      t.integer :winner, null: false
      t.integer :batting_style, null: false
      t.timestamps
    end

    add_index :rallies, [:match_info_id, :game_number, :sequence_number], unique: true,
                                                                          name: 'index_rallies_on_match_info_game_sequence'
  end
end
