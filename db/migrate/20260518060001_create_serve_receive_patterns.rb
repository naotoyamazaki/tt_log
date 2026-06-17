class CreateServeReceivePatterns < ActiveRecord::Migration[7.1]
  def change
    create_table :serve_receive_patterns do |t|
      t.references :match_info, null: false, foreign_key: true
      t.references :game, null: true, foreign_key: true
      t.integer :game_number, null: false
      t.integer :sequence_number, null: false
      t.integer :origin, null: false
      t.integer :serve_length
      t.integer :serve_spins, array: true, default: []
      t.integer :receive_style
      t.integer :attack_style, null: false
      t.integer :decided_at, null: false
      t.boolean :won, null: false
      t.timestamps
    end
    add_index :serve_receive_patterns, [:match_info_id, :game_number, :sequence_number],
              unique: true, name: 'index_srp_on_match_info_game_sequence'
  end
end
