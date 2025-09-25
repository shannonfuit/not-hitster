class CreateSongs < ActiveRecord::Migration[8.0]
  def change
    create_table :songs do |t|
      t.string :artist, null: false
      t.string :title, null: false
      t.integer :release_year, null: false
      t.string :spotify_uuid, null: false
      t.string :qr_token, null: false
      t.index :qr_token, unique: true

      t.timestamps
    end
  end
end
