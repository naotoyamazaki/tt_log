class CreateAiUsageLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_usage_logs do |t|
      t.bigint :user_id
      t.bigint :match_info_id
      t.string :feature, null: false
      t.string :model
      t.boolean :success, null: false, default: false
      t.string :error_kind
      t.integer :duration_ms
      t.integer :prompt_tokens
      t.integer :completion_tokens
      t.integer :total_tokens
      t.datetime :created_at, null: false
    end
    add_index :ai_usage_logs, [:user_id, :feature, :created_at]
    add_foreign_key :ai_usage_logs, :users, on_delete: :nullify
  end
end
