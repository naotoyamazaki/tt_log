class AddResetPasswordFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :reset_password_token, :string
    add_column :users, :reset_password_token_expires_at, :datetime
    add_column :users, :reset_password_email_sent_at, :datetime

    add_index :users, :reset_password_token, unique: true
  end
end
