class RemoveRememberDigestFromUsers < ActiveRecord::Migration[7.1]
  def change
    remove_column :users, :remember_digest, :string
  end
end
