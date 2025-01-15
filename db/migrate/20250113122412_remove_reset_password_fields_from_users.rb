class RemoveResetPasswordFieldsFromUsers < ActiveRecord::Migration[7.1]
  def change
    remove_column :users, :reset_password_token, :string
    remove_column :users, :reset_password_token_expires_at, :datetime
    remove_column :users, :reset_password_email_sent_at, :datetime
  end
end
