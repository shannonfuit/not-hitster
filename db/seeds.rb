require "json"

songs_path = Rails.root.join("db", "seeds", "songs.json")

if File.exist?(songs_path)
  data = JSON.parse(File.read(songs_path))

  data.each do |attrs|
    song = Song.find_or_create_by!(qr_token: attrs["qr_token"]) do |s|
      s.artist       = attrs["artist"]
      s.title        = attrs["title"]
      s.release_year = attrs["release_year"]
      s.spotify_uuid = attrs["spotify_uuid"]
    end

    playlist_data = Array(attrs["playlists"]).presence || [ { "name" => "All Songs", "spotify_url" => nil } ]
    playlist_data.each do |pl_attrs|
      playlist = Playlist.find_or_create_by!(name: pl_attrs["name"]) do |pl|
        pl.spotify_url = pl_attrs["spotify_url"]
      end
      PlaylistSong.find_or_create_by!(playlist:, song:)
    end
  end

  puts "✅ Seeded #{data.size} songs with playlists from #{songs_path}"
else
  puts "ℹ️  No songs.json at #{songs_path}, skipping seeding"
end
