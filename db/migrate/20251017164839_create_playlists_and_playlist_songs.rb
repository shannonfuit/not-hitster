class CreatePlaylistsAndPlaylistSongs < ActiveRecord::Migration[8.0]
  def up
    create_table :playlists do |t|
      t.string :name, null: false
      t.string :spotify_url, null: false
      t.timestamps
    end
    add_index :playlists, :name, unique: true

    create_table :playlist_songs do |t|
      t.references :playlist, null: false, foreign_key: true
      t.references :song,     null: false, foreign_key: true
      t.timestamps
    end
    add_index :playlist_songs, [ :playlist_id, :song_id ], unique: true, name: "index_playlist_songs_on_pl_and_song"

    drop_table :playlists_songs if table_exists?(:playlists_songs)

    # Backfill
    say_with_time "Creating 'Bart's Hits' playlist and linking all songs" do
      playlist_model      = Class.new(ActiveRecord::Base) { self.table_name = "playlists" }
      song_model          = Class.new(ActiveRecord::Base) { self.table_name = "songs" }
      playlist_song_model = Class.new(ActiveRecord::Base) { self.table_name = "playlist_songs" }

      song_ids = song_model.pluck(:id)
      if song_ids.any?
        default = playlist_model.find_or_create_by!(name: "Bart's Hits", spotify_url: "https://open.spotify.com/playlist/22PTadBrGYNPU27fvPmNGx?si=5NvZ6HfaR4OHMDnwIydY6w")
        now = Time.current

        rows = song_ids.map { |sid| { playlist_id: default.id, song_id: sid, created_at: now, updated_at: now } }

        # ✅ Call on a model, not on the connection
        playlist_song_model.insert_all(
          rows,
          unique_by: "index_playlist_songs_on_pl_and_song" # your unique index name
        )
      end
    end
  end

  def down
    drop_table :playlist_songs if table_exists?(:playlist_songs)
    remove_index :playlists, :name if index_exists?(:playlists, :name)
    drop_table :playlists if table_exists?(:playlists)
  end
end
