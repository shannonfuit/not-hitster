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

    playlist_names = Array(attrs["playlists"]).presence || [ "All Songs" ]
    playlist_names.each do |name|
      playlist = Playlist.find_or_create_by!(name:)
      PlaylistSong.find_or_create_by!(playlist:, song:)
    end
  end

  puts "✅ Seeded #{data.size} songs with playlists from #{songs_path}"
else
  puts "ℹ️  No songs.json at #{songs_path}, skipping seeding"
end
