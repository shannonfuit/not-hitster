class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :spotify_uid
      t.string :display_name
      t.string :email
      t.string :avatar_url
      t.text :access_token
      t.text :refresh_token
      t.datetime :token_expires_at

      t.timestamps
    end
    add_index :users, :spotify_uid
  end
end
